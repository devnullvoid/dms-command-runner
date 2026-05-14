import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string trigger: ">"
    property var commandHistory: []
    property int maxHistoryItems: 20
    property string pendingCompletionQuery: ""
    property string completionQuery: ""
    property var completionItems: []
    property string completionOutput: ""
    property var executableCache: []
    property var homePathCache: []
    property string homePathOutput: ""

    signal itemsChanged

    property Process completionProcess: Process {
        id: completionProcess
        running: false

        stdout: StdioCollector {
            id: completionCollector
            property int lastLength: 0

            onTextChanged: {
                const current = text || "";
                if (current.length < lastLength)
                    lastLength = 0;
                root.completionOutput += current.substring(lastLength);
                lastLength = current.length;
            }
        }

        onExited: exitCode => {
            const query = root.pendingCompletionQuery;
            root.pendingCompletionQuery = "";

            if (exitCode !== 0 || !query)
                return;

            const lines = root.completionOutput.split("\n");
            const nextItems = [];
            const seen = {};

            for (let i = 0; i < lines.length; i++) {
                const candidate = lines[i].trim();
                if (!candidate || candidate === query || seen[candidate])
                    continue;
                seen[candidate] = true;
                nextItems.push(candidate);
                if (nextItems.length >= 8)
                    break;
            }

            completionQuery = query;
            completionItems = nextItems;
            itemsChanged();
        }
    }

    property Process executableCacheProcess: Process {
        id: executableCacheProcess
        running: false

        stdout: StdioCollector {
            id: executableCacheCollector
            property int lastLength: 0

            onTextChanged: {
                const current = text || "";
                if (current.length < lastLength)
                    lastLength = 0;
                root.completionOutput += current.substring(lastLength);
                lastLength = current.length;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                return;

            const lines = root.completionOutput.split("\n");
            const nextExecutables = [];
            const seen = {};

            for (let i = 0; i < lines.length; i++) {
                const candidate = lines[i].trim();
                if (!candidate || seen[candidate])
                    continue;
                seen[candidate] = true;
                nextExecutables.push(candidate);
            }

            executableCache = nextExecutables;
        }
    }

    property Process homePathCacheProcess: Process {
        id: homePathCacheProcess
        running: false

        stdout: StdioCollector {
            id: homePathCacheCollector
            property int lastLength: 0

            onTextChanged: {
                const current = text || "";
                if (current.length < lastLength)
                    lastLength = 0;
                root.homePathOutput += current.substring(lastLength);
                lastLength = current.length;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                return;

            const lines = root.homePathOutput.split("\n");
            const nextEntries = [];
            const seen = {};

            for (let i = 0; i < lines.length; i++) {
                const candidate = lines[i].trim();
                if (!candidate || seen[candidate])
                    continue;
                seen[candidate] = true;
                nextEntries.push(candidate);
            }

            homePathCache = nextEntries;
        }
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("commandRunner", "trigger", ">");
        commandHistory = pluginService.loadPluginData("commandRunner", "history", []);
        maxHistoryItems = pluginService.loadPluginData("commandRunner", "maxHistoryItems", 20);
        refreshExecutableCache();
        refreshHomePathCache();
    }

    function getItems(query) {
        const items = [];
        const trimmedQuery = query ? query.trim() : "";

        updateCompletionSuggestions(trimmedQuery);

        if (trimmedQuery.length > 0) {
            if (completionQuery === trimmedQuery && completionItems.length > 0) {
                for (let i = 0; i < completionItems.length; i++) {
                    const suggestion = completionItems[i];
                    items.push({
                        name: suggestion,
                        icon: "material:tab",
                        comment: "Autocomplete suggestion · Enter: run · Shift+Enter: run in background",
                        action: "run:" + suggestion,
                        categories: ["Command Runner"],
                        _preScored: 1100 - i
                    });
                }
            }

            // Use _preScored to ensure DMS preserves our item ordering
            items.push({
                name: "Run: " + trimmedQuery,
                icon: "material:terminal",
                comment: "Execute command in terminal",
                action: "run:" + trimmedQuery,
                categories: ["Command Runner"],
                _preScored: 1000
            });

            items.push({
                name: "Run in background: " + trimmedQuery,
                icon: "material:step_over",
                comment: "Execute command silently in background",
                action: "background:" + trimmedQuery,
                categories: ["Command Runner"],
                _preScored: 900
            });

            items.push({
                name: "Copy: " + trimmedQuery,
                icon: "material:content_copy",
                comment: "Copy command to clipboard",
                action: "copy:" + trimmedQuery,
                categories: ["Command Runner"],
                _preScored: 800
            });
        }

        if (commandHistory.length > 0) {
            const filteredHistory = trimmedQuery ? commandHistory.filter(cmd => cmd.toLowerCase().includes(trimmedQuery.toLowerCase())) : commandHistory;

            for (let i = 0; i < Math.min(10, filteredHistory.length); i++) {
                const cmd = filteredHistory[i];
                items.push({
                    name: cmd,
                    icon: "material:history",
                    comment: "Run from history · Shift+Enter: run in background",
                    action: "run:" + cmd,
                    categories: ["Command Runner"],
                    _preScored: 100 - i
                });
            }
        }

        return items;
    }

    function updateCompletionSuggestions(query) {
        if (!query) {
            pendingCompletionQuery = "";
            completionQuery = "";
            completionItems = [];
            return;
        }

        if (completionProcess.running)
            return;
        if (completionQuery === query)
            return;

        if (query.indexOf(" ") === -1 && query.indexOf("/") === -1 && !query.startsWith("~")) {
            completionQuery = query;
            completionItems = filterExecutableCache(query);
            return;
        }

        const cachedHomeMatches = filterHomePathCache(query);
        if (cachedHomeMatches.length > 0) {
            completionQuery = query;
            completionItems = cachedHomeMatches;
            return;
        }

        pendingCompletionQuery = query;
        completionOutput = "";
        completionCollector.lastLength = (completionCollector.text || "").length;
        completionProcess.command = [
            "bash",
            "-lc",
            "query=\"$1\"; " +
            "current=\"${query##* }\"; " +
            "prefix=\"${query%\"$current\"}\"; " +
            "if [ \"$prefix\" = \"$query\" ]; then prefix=\"\"; fi; " +
            "if [[ \"$current\" == ~* ]]; then expanded_current=\"${current/#\\~/$HOME}\"; else expanded_current=\"$current\"; fi; " +
            "if [[ \"$query\" != *' '* && \"$current\" != */* && \"$current\" != ~* ]]; then " +
            "  compgen -c -- \"$current\" | awk '!seen[$0]++ { print $0 }'; " +
            "else " +
            "  compgen -f -- \"$expanded_current\" | while IFS= read -r candidate; do " +
            "    output=\"$candidate\"; " +
            "    if [[ \"$current\" == ~* ]]; then output=\"~${candidate#$HOME}\"; fi; " +
            "    if [ -d \"$candidate\" ]; then output=\"$output/\"; fi; " +
            "    printf '%s%s\\n' \"$prefix\" \"$output\"; " +
            "  done | awk '!seen[$0]++ { print $0 }'; " +
            "fi",
            "completion",
            query
        ];
        completionProcess.running = true;
    }

    function refreshExecutableCache() {
        if (executableCacheProcess.running)
            return;

        completionOutput = "";
        executableCacheCollector.lastLength = (executableCacheCollector.text || "").length;
        executableCacheProcess.command = [
            "bash",
            "-lc",
            "compgen -c | awk '!seen[$0]++ { print $0 }'"
        ];
        executableCacheProcess.running = true;
    }

    function refreshHomePathCache() {
        if (homePathCacheProcess.running)
            return;

        homePathOutput = "";
        homePathCacheCollector.lastLength = (homePathCacheCollector.text || "").length;
        homePathCacheProcess.command = [
            "bash",
            "-lc",
            "cd \"$HOME\" 2>/dev/null && find . -mindepth 1 -maxdepth 6 \\( -type d -printf '%P/\\n' -o -printf '%P\\n' \\) 2>/dev/null | awk '!seen[$0]++ { print $0 }'"
        ];
        homePathCacheProcess.running = true;
    }

    function filterExecutableCache(query) {
        if (!query)
            return [];

        const lowered = query.toLowerCase();
        const matches = [];

        for (let i = 0; i < executableCache.length; i++) {
            const candidate = executableCache[i];
            const name = String(candidate || "");
            const lowerName = name.toLowerCase();

            if (!lowerName.startsWith(lowered))
                continue;

            matches.push(name);
            if (matches.length >= 8)
                break;
        }

        return matches;
    }

    function filterHomePathCache(query) {
        if (!query)
            return [];

        const current = query.indexOf(" ") >= 0 ? query.substring(query.lastIndexOf(" ") + 1) : query;
        if (!current.startsWith("~/"))
            return [];

        const typed = current.substring(2).toLowerCase();
        const prefix = query.substring(0, query.length - current.length);
        const matches = [];

        for (let i = 0; i < homePathCache.length; i++) {
            const entry = String(homePathCache[i] || "");
            if (!entry.toLowerCase().startsWith(typed))
                continue;

            matches.push(prefix + "~/" + entry);
            if (matches.length >= 8)
                break;
        }

        return matches;
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;
        const actionParts = item.action.split(":");
        const actionType = actionParts[0];
        const command = actionParts.slice(1).join(":");

        switch (actionType) {
        case "noop":
            return;
        case "copy":
            copyToClipboard(command);
            break;
        case "run":
            runCommand(command);
            break;
        case "background":
            runBackground(command);
            break;
        default:
            showToast("Unknown action: " + actionType);
        }
    }

    // Returns the command string for "run:" items; used by getPasteArgs.
    function getPasteText(item) {
        if (!item || !item.action)
            return null;
        const actionParts = item.action.split(":");
        if (actionParts[0] !== "run")
            return null;
        return actionParts.slice(1).join(":");
    }

    // Called by DMS on Shift+Enter: runs the command in background instead of
    // opening a terminal window.
    function getPasteArgs(item) {
        const command = getPasteText(item);
        if (!command)
            return null;
        return ["sh", "-c", command];
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + text + "' | wl-copy"]);
        showToast("Copied to clipboard: " + text);
    }

    function runCommand(command) {
        addToHistory(command);
        const terminal = getTerminalCommand();
        const wrappedCommand = command + "; echo '\nPress Enter to close...'; read";
        Quickshell.execDetached([terminal.cmd, terminal.execFlag, "sh", "-c", wrappedCommand]);
        showToast("Running in " + terminal.cmd + ": " + command);
    }

    function runBackground(command) {
        addToHistory(command);
        Quickshell.execDetached(["sh", "-c", command]);
        showToast("Running in background: " + command);
    }

    function showToast(message) {
        if (typeof ToastService !== "undefined") {
            ToastService.showInfo("Command Runner", message);
        }
    }

    function getTerminalCommand() {
        if (pluginService) {
            const terminal = pluginService.loadPluginData("commandRunner", "terminal", "kitty");
            const execFlag = pluginService.loadPluginData("commandRunner", "execFlag", "-e");
            if (terminal && execFlag) {
                return {
                    cmd: terminal,
                    execFlag: execFlag
                };
            }
        }
        return {
            cmd: "kitty",
            execFlag: "-e"
        };
    }

    function addToHistory(command) {
        const index = commandHistory.indexOf(command);
        if (index > -1) {
            commandHistory.splice(index, 1);
        }

        commandHistory.unshift(command);

        if (commandHistory.length > maxHistoryItems) {
            commandHistory = commandHistory.slice(0, maxHistoryItems);
        }

        if (pluginService) {
            pluginService.savePluginData("commandRunner", "history", commandHistory);
        }

        itemsChanged();
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("commandRunner", "trigger", trigger);
        itemsChanged();
    }
}
