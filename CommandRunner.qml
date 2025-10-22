import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: ">"
    property var commandHistory: []
    property int maxHistoryItems: 20

    signal itemsChanged()

    Component.onCompleted: {
        console.log("CommandRunner: Plugin loaded")

        if (pluginService) {
            trigger = pluginService.loadPluginData("commandRunner", "trigger", ">")
            commandHistory = pluginService.loadPluginData("commandRunner", "history", [])
            maxHistoryItems = pluginService.loadPluginData("commandRunner", "maxHistoryItems", 20)
        }
    }

    function getItems(query) {
        const items = []

        if (query && query.trim().length > 0) {
            const command = query.trim()

            items.push({
                name: "Run: " + command,
                icon: "terminal",
                comment: "Execute command in terminal",
                action: "run:" + command,
                categories: ["Command Runner"]
            })

            items.push({
                name: "Run in background: " + command,
                icon: "system-run",
                comment: "Execute command silently in background",
                action: "background:" + command,
                categories: ["Command Runner"]
            })

            items.push({
                name: "Copy: " + command,
                icon: "edit-copy",
                comment: "Copy command to clipboard",
                action: "copy:" + command,
                categories: ["Command Runner"]
            })
        }

        if (commandHistory.length > 0) {
            const historyHeader = {
                name: "──────── Recent Commands ────────",
                icon: "history",
                comment: "Commands from your history",
                action: "noop",
                categories: ["Command Runner"]
            }
            items.push(historyHeader)

            const filteredHistory = query
                ? commandHistory.filter(cmd => cmd.toLowerCase().includes(query.toLowerCase()))
                : commandHistory

            for (let i = 0; i < Math.min(10, filteredHistory.length); i++) {
                const cmd = filteredHistory[i]
                items.push({
                    name: cmd,
                    icon: "history",
                    comment: "Run from history",
                    action: "run:" + cmd,
                    categories: ["Command Runner"]
                })
            }
        }



        return items
    }

    function executeItem(item) {
        if (!item || !item.action) {
            console.warn("CommandRunner: Invalid item or action")
            return
        }

        console.log("CommandRunner: Executing item:", item.name, "with action:", item.action)

        const actionParts = item.action.split(":")
        const actionType = actionParts[0]
        const command = actionParts.slice(1).join(":")

        switch (actionType) {
            case "noop":
                return
            case "copy":
                copyToClipboard(command)
                break
            case "run":
                runCommand(command)
                break
            case "background":
                runBackground(command)
                break
            default:
                console.warn("CommandRunner: Unknown action type:", actionType)
                showToast("Unknown action: " + actionType)
        }
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + text + "' | wl-copy"])
        showToast("Copied to clipboard: " + text)
    }

    function runCommand(command) {
        addToHistory(command)
        const terminal = getTerminalCommand()
        const wrappedCommand = command + "; echo '\nPress Enter to close...'; read"
        Quickshell.execDetached([terminal.cmd, terminal.execFlag, "sh", "-c", wrappedCommand])
        showToast("Running in " + terminal.cmd + ": " + command)
    }

    function runBackground(command) {
        addToHistory(command)
        Quickshell.execDetached(["sh", "-c", command])
        showToast("Running in background: " + command)
    }

    function showToast(message) {
        if (typeof ToastService !== "undefined") {
            ToastService.showInfo("Command Runner", message)
        } else {
            console.log("CommandRunner Toast:", message)
        }
    }

    function getTerminalCommand() {
        if (pluginService) {
            const terminal = pluginService.loadPluginData("commandRunner", "terminal", "kitty")
            const execFlag = pluginService.loadPluginData("commandRunner", "execFlag", "-e")
            if (terminal && execFlag) {
                return {cmd: terminal, execFlag: execFlag}
            }
        }

        return {cmd: "kitty", execFlag: "-e"}
    }

    function addToHistory(command) {
        const index = commandHistory.indexOf(command)
        if (index > -1) {
            commandHistory.splice(index, 1)
        }

        commandHistory.unshift(command)

        if (commandHistory.length > maxHistoryItems) {
            commandHistory = commandHistory.slice(0, maxHistoryItems)
        }

        if (pluginService) {
            pluginService.savePluginData("commandRunner", "history", commandHistory)
        }

        itemsChanged()
    }

    onTriggerChanged: {
        if (pluginService) {
            pluginService.savePluginData("commandRunner", "trigger", trigger)
        }
        itemsChanged()
    }
}
