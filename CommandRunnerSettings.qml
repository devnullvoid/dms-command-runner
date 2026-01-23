import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "commandRunner"

    StyledText {
        width: parent.width
        text: "Command Runner"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Execute shell commands directly from the launcher with history tracking."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        id: noTriggerToggle
        settingKey: "noTrigger"
        label: "Always Active"
        description: value ? "Items will always show in the launcher (no trigger needed)." : "Set the trigger text to activate this plugin. Type the trigger in the launcher to run commands."
        defaultValue: false
        onValueChanged: {
            if (value) {
                root.saveValue("trigger", "");
            } else {
                root.saveValue("trigger", triggerSetting.value || ">");
            }
        }
    }

    StringSetting {
        id: triggerSetting
        visible: !noTriggerToggle.value
        settingKey: "trigger"
        label: "Trigger"
        description: "Prefix character(s) to activate command runner (e.g., >, $, !, run). Avoid triggers reserved by DMS or other plugins (e.g., / for file search)."
        placeholder: ">"
        defaultValue: ">"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Terminal Configuration"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure which terminal emulator to use for commands"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        Column {
            width: (parent.width - Theme.spacingM) / 2
            spacing: Theme.spacingXS

            StyledText {
                text: "Terminal"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: terminalField
                width: parent.width
                text: root.loadValue("terminal", "kitty")
                placeholderText: "kitty"
                onTextEdited: root.saveValue("terminal", text.trim())
            }
        }

        Column {
            width: (parent.width - Theme.spacingM) / 2
            spacing: Theme.spacingXS

            StyledText {
                text: "Exec Flag"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: execFlagField
                width: parent.width
                text: root.loadValue("execFlag", "-e")
                placeholderText: "-e"
                onTextEdited: root.saveValue("execFlag", text.trim())
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Common: kitty (-e), alacritty (-e), foot (-e), wezterm (start), gnome-terminal (--), konsole (-e)"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        leftPadding: Theme.spacingM
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "History Settings"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: "Max history items:"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        DankTextField {
            id: historyField
            width: 80
            text: root.loadValue("maxHistoryItems", "20").toString()
            placeholderText: "20"
            onTextEdited: {
                const num = parseInt(text);
                if (!isNaN(num) && num > 0 && num <= 100) {
                    root.saveValue("maxHistoryItems", num);
                }
            }
        }

        StyledText {
            text: "(1-100)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    DankButton {
        text: "Clear Command History"
        iconName: "delete"
        backgroundColor: Theme.error
        textColor: Theme.surface
        onClicked: {
            root.saveValue("history", []);
            ToastService?.showInfo("Command history cleared");
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Features"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM

        Repeater {
            model: ["Run commands in terminal or background", "Command history with recent commands", "Copy commands to clipboard", "Configurable terminal emulator"]

            StyledText {
                required property string modelData
                text: "• " + modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Usage"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM
        bottomPadding: Theme.spacingL

        Repeater {
            model: ["1. Open Launcher (Ctrl+Space or click launcher button)", noTriggerToggle.value ? "2. Commands are always visible in the launcher" : "2. Type your trigger (default: >) followed by command", noTriggerToggle.value ? "3. Type your command, e.g., 'htop' or 'ls -la'" : "3. Example: '> htop' or '> ls -la'", "4. Select 'Run' for terminal, 'Run in background' for silent execution", "5. Browse recent commands from history"]

            StyledText {
                required property string modelData
                text: modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
