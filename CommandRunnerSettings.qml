import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    implicitHeight: settingsColumn.implicitHeight
    height: implicitHeight

    Column {
        id: settingsColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        StyledText {
            text: "Command Runner Settings"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: "Execute shell commands directly from the launcher with history tracking."
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width - 32
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 12
            width: parent.width - 32

            StyledText {
                text: "Trigger Configuration"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: noTriggerToggle.checked ? "Items will always show in the launcher (no trigger needed)." : "Set the trigger text to activate this plugin. Type the trigger in the launcher to run commands."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Row {
                spacing: 12

                CheckBox {
                    id: noTriggerToggle
                    text: "No trigger (always show)"
                    checked: loadSettings("noTrigger", false)

                    contentItem: StyledText {
                        text: noTriggerToggle.text
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        leftPadding: noTriggerToggle.indicator.width + 8
                        verticalAlignment: Text.AlignVCenter
                    }

                    indicator: StyledRect {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: Theme.cornerRadiusSmall
                        border.color: noTriggerToggle.checked ? Theme.primary : Theme.outline
                        border.width: 2
                        color: noTriggerToggle.checked ? Theme.primary : "transparent"

                        StyledRect {
                            width: 12
                            height: 12
                            anchors.centerIn: parent
                            radius: 2
                            color: Theme.onPrimary
                            visible: noTriggerToggle.checked
                        }
                    }

                    onCheckedChanged: {
                        saveSettings("noTrigger", checked)
                        if (checked) {
                            saveSettings("trigger", "")
                        } else {
                            saveSettings("trigger", triggerField.text || ">")
                        }
                    }
                }
            }

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.right: parent.right
                visible: !noTriggerToggle.checked

                StyledText {
                    text: "Trigger:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankTextField {
                    id: triggerField
                    width: 100
                    height: 40
                    text: loadSettings("trigger", ">")
                    placeholderText: ">"
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText

                    onTextEdited: {
                        const newTrigger = text.trim()
                        saveSettings("trigger", newTrigger || ">")
                        saveSettings("noTrigger", newTrigger === "")
                    }
                }

                StyledText {
                    text: "Examples: >, $, !, /run, etc."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 12
            width: parent.width - 32

            StyledText {
                text: "Terminal Configuration"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: "Configure which terminal emulator to use for commands"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Row {
                spacing: 12
                width: parent.width

                StyledText {
                    text: "Terminal:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankTextField {
                    id: terminalField
                    width: 150
                    height: 40
                    text: loadSettings("terminal", "kitty")
                    placeholderText: "kitty"
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText

                    onTextEdited: {
                        saveSettings("terminal", text.trim())
                    }
                }

                StyledText {
                    text: "Exec flag:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankTextField {
                    id: execFlagField
                    width: 80
                    height: 40
                    text: loadSettings("execFlag", "-e")
                    placeholderText: "-e"
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText

                    onTextEdited: {
                        saveSettings("execFlag", text.trim())
                    }
                }
            }

            Column {
                spacing: 4
                leftPadding: 16

                StyledText {
                    text: "Common terminals: kitty (-e), alacritty (-e), foot (-e), wezterm (start)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "Others: gnome-terminal (--), konsole (-e), xterm (-e)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 12
            width: parent.width - 32

            StyledText {
                text: "History Settings"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Row {
                spacing: 12
                width: parent.width

                StyledText {
                    text: "Max history items:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankTextField {
                    id: historyField
                    width: 80
                    height: 40
                    text: loadSettings("maxHistoryItems", "20")
                    placeholderText: "20"
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText

                    onTextEdited: {
                        const num = parseInt(text)
                        if (!isNaN(num) && num > 0 && num <= 100) {
                            saveSettings("maxHistoryItems", num)
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

            StyledRect {
                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: clearMouseArea.containsMouse ? Theme.errorHover : Theme.error

                StyledText {
                    anchors.centerIn: parent
                    text: "Clear Command History"
                    color: Theme.onError
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: clearMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        saveSettings("history", [])
                        if (typeof ToastService !== "undefined") {
                            ToastService.showInfo("Command history cleared")
                        }
                    }
                }
            }
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 8
            width: parent.width - 32

            StyledText {
                text: "Features:"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                spacing: 4
                leftPadding: 16

                StyledText {
                    text: "• Run commands in terminal or background"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• Command history with recent commands"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• Common command shortcuts"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• Copy commands to clipboard"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• Auto-detects available terminal emulator"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 8
            width: parent.width - 32

            StyledText {
                text: "Usage:"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                spacing: 4
                leftPadding: 16
                bottomPadding: 24

                StyledText {
                    text: "1. Open Launcher (Ctrl+Space or click launcher button)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: noTriggerToggle.checked ? "2. Commands are always visible in the launcher" : "2. Type your trigger (default: >) followed by command"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: noTriggerToggle.checked ? "3. Type your command, e.g., 'htop' or 'ls -la'" : "3. Example: '> htop' or '> ls -la'"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "4. Select 'Run' to open in terminal, 'Run in background' for silent execution"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "5. Browse recent commands from history or pick from common commands"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    function saveSettings(key, value) {
        if (pluginService) {
            pluginService.savePluginData("commandRunner", key, value)
        }
    }

    function loadSettings(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData("commandRunner", key, defaultValue)
        }
        return defaultValue
    }
}
