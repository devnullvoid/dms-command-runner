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

    signal itemsChanged

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("commandRunner", "trigger", ">");
        commandHistory = pluginService.loadPluginData("commandRunner", "history", []);
        maxHistoryItems = pluginService.loadPluginData("commandRunner", "maxHistoryItems", 20);
    }

    function getItems(query) {
        const items = [];

        if (query && query.trim().length > 0) {
            const command = query.trim();

            items.push({
                name: "Run: " + command,
                icon: "material:terminal",
                comment: "Execute command in terminal",
                action: "run:" + command,
                categories: ["Command Runner"]
            });

            items.push({
                name: "Run in background: " + command,
                icon: "material:step_over",
                comment: "Execute command silently in background",
                action: "background:" + command,
                categories: ["Command Runner"]
            });

            items.push({
                name: "Copy: " + command,
                icon: "material:content_copy",
                comment: "Copy command to clipboard",
                action: "copy:" + command,
                categories: ["Command Runner"]
            });
        }

        if (commandHistory.length > 0) {
            const filteredHistory = query ? commandHistory.filter(cmd => cmd.toLowerCase().includes(query.toLowerCase())) : commandHistory;

            for (let i = 0; i < Math.min(10, filteredHistory.length); i++) {
                const cmd = filteredHistory[i];
                items.push({
                    name: cmd,
                    icon: "material:history",
                    comment: "Run from history",
                    action: "run:" + cmd,
                    categories: ["Command Runner"]
                });
            }
        }

        return items;
    }

    function executeItem(item) {
        if (!item?.action)
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
