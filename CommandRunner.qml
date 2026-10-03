import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import "CommandRunnerHelpers.js" as Helpers

QtObject {
    id: root

    property var pluginService: null
    property string trigger: ">"
    property var commandHistory: []
    property int maxHistoryItems: 20
    property string pendingCompletionQuery: ""
    property string latestCompletionQuery: ""
    property string completionQuery: ""
    property var completionItems: []

    signal itemsChanged

    onItemsChanged: {
        // DMS's launcher refreshes through PluginService, not the plugin's
        // local signal. Async results must notify it without a new keystroke.
        if (pluginService && typeof pluginService.requestLauncherUpdate === "function")
            pluginService.requestLauncherUpdate("commandRunner");
    }

    property Process completionProcess: Process {
        id: completionProcess
        running: false

        stdout: StdioCollector {
            id: completionCollector
            // The producer limits output before it reaches QML. Do not retain
            // duplicate buffers or a recursive cache of the user's home tree.
            onStreamFinished: {
                const query = root.pendingCompletionQuery;
                if (!query || query !== root.latestCompletionQuery)
                    return;
                root.completionQuery = query;
                root.completionItems = Helpers.parseCompletions(text, query);
                root.itemsChanged();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.pendingCompletionQuery === root.latestCompletionQuery) {
                root.completionQuery = root.pendingCompletionQuery;
                root.completionItems = [];
                root.itemsChanged();
            }
            root.pendingCompletionQuery = "";
            // A query typed while this process was running must not require
            // another keystroke before its suggestions become available.
            root.updateCompletionSuggestions(root.latestCompletionQuery);
        }
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("commandRunner", "trigger", ">");
        commandHistory = pluginService.loadPluginData("commandRunner", "history", []);
        maxHistoryItems = pluginService.loadPluginData("commandRunner", "maxHistoryItems", 20);
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
                        comment: "Autocomplete suggestion · Enter: run · Shift+Enter: paste output",
                        action: "run:" + suggestion,
                        categories: ["Command Runner"],
                        _preScored: 950 - i
                    });
                }
            }

            // Use _preScored to ensure DMS preserves our item ordering
            items.push({
                name: "Run: " + trimmedQuery,
                icon: "material:terminal",
                comment: "Enter: run in terminal · Shift+Enter: paste output",
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
                    comment: "Run from history · Shift+Enter: paste output",
                    action: "run:" + cmd,
                    categories: ["Command Runner"],
                    _preScored: 100 - i
                });
            }
        }

        return items;
    }

    function updateCompletionSuggestions(query) {
        latestCompletionQuery = query;
        if (!query) {
            completionQuery = "";
            completionItems = [];
            return;
        }

        if (completionProcess.running)
            return;
        if (completionQuery === query)
            return;

        pendingCompletionQuery = query;
        completionProcess.command = Helpers.completionArgs(query);
        completionProcess.running = true;
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

    // DMS waits for these arguments to finish before sending a paste keystroke.
    function getPasteArgs(item) {
        const command = getPasteText(item);
        if (!command)
            return null;
        addToHistory(command);
        return Helpers.pasteArgs(command);
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
