# Command Runner

A DankMaterialShell launcher plugin for executing shell commands directly from the launcher with history tracking and preset shortcuts.

![Command Runner Screenshot](screenshot.png)

## Features

- **Execute Commands** - Run any shell command in terminal or background
- **Autocomplete Suggestions** - Shell-style command and path suggestions appear as you type
- **Command History** - Track and reuse recently executed commands
- **Common Shortcuts** - Quick access to frequently used commands (htop, btop, ncdu, etc.)
- **Terminal Support** - Auto-detect or configure your preferred terminal emulator
- **Background Execution** - Run commands silently without opening a terminal
- **Clipboard Copy** - Copy commands to clipboard before executing
- **Paste Command Output** - Shift+Enter runs a command and pastes its stdout into the focused application
- **Configurable Trigger** - Default `>` or set your own trigger

## Installation

### From Plugin Registry (Recommended)
```bash
# Coming soon - will be available via DMS plugin manager
```

### Manual Installation
```bash
# Copy plugin to DMS plugins directory
cp -r CommandRunner ~/.config/DankMaterialShell/plugins/

# Enable in DMS
# 1. Open Settings (Ctrl+,)
# 2. Go to Plugins tab
# 3. Click "Scan for Plugins"
# 4. Toggle "Command Runner" to enable
# 5. Configure your terminal emulator in plugin settings
```

## Configuration

**Important**: Configure your terminal before first use!

1. Open Settings → Plugins → Command Runner
2. Set **Terminal**: Your terminal emulator (e.g., `kitty`, `alacritty`, `foot`)
3. Set **Exec flag**: The flag for executing commands (e.g., `-e` for most terminals)

### Common Terminal Configurations

| Terminal | Command | Exec Flag |
|----------|---------|-----------|
| kitty | `kitty` | `-e` |
| alacritty | `alacritty` | `-e` |
| foot | `foot` | `-e` |
| wezterm | `wezterm` | `start` |
| gnome-terminal | `gnome-terminal` | `--` |
| konsole | `konsole` | `-e` |
| xterm | `xterm` | `-e` |

## Usage

### Execute Commands in Terminal
Note: Avoid triggers reserved by DMS or other plugins (e.g., `/` is used for file search).

1. Open launcher (Ctrl+Space)
2. Type `>` followed by command
3. Examples:
   - `> htop` - System monitor
   - `> btop` - Modern resource monitor
   - `> ls -la` - List files with details
   - `> journalctl -f` - View live system logs
4. Select "Run: command" and press Enter

### Autocomplete Suggestions
- Start typing a command name to see executable suggestions
- Type part of a path after a space (for example `> ls ~/Do`) to see file and directory suggestions
- Select a suggestion to run the completed command directly
- Completion searches the current command or directory on demand and returns at most eight suggestions; it does not scan your home directory recursively at startup

### Execute Commands in Background
1. Type command as above
2. Select "Run in background: command"
3. Command executes silently without terminal window

### Paste Command Output

1. Focus the text field where you want the output
2. Open the launcher and enter a finite command, such as `> echo hello`
3. Select its "Run" entry, an autocomplete suggestion, or a history entry and press Shift+Enter
4. The command's stdout replaces the clipboard, then DMS pastes it into the previously focused application

Commands run with Shift+Enter are added to history just like terminal and background runs.

Multiline output and trailing newlines are preserved. Stderr is not copied. An empty stdout replaces the clipboard with empty text, including when a command fails without producing stdout. Use the explicit "Run in background" entry for background execution. Paste requires DMS clipboard/paste support and `wl-copy`; DMS controls paste timing and process lifetime.

### Copy Command to Clipboard
1. Type command
2. Select "Copy: command"
3. Command copied to clipboard for use elsewhere

### Use Command History
- Recent commands appear automatically in the list
- Click any historical command to re-execute
- History persists across sessions
- Autocomplete suggestions are shown ahead of history when available

### Common Command Shortcuts
Access pre-configured shortcuts without typing:
- `htop` - Interactive process viewer
- `btop` - Resource monitor
- `ncdu` - Disk usage analyzer
- `nmtui` - Network manager TUI
- `ranger` - File manager
- `neofetch` / `fastfetch` - System info
- And more!

## Settings

- **Trigger**: Set custom trigger (`>`, `$`, `!`, `run`, etc.) or disable for always-on
  - Avoid triggers reserved by DMS or other plugins (e.g., `/` is used for file search).
- **Terminal Emulator**: Configure which terminal to use
- **Exec Flag**: Set the command execution flag for your terminal
- **Max History Items**: Configure history size (1-100 items)
- **Clear History**: Remove all stored commands

## Examples

### System Monitoring
```
> htop              # Interactive process viewer
> btop              # Modern resource monitor
> journalctl -f     # Live system logs
> df -h             # Disk usage
> free -h           # Memory usage
```

### File Operations
```
> ls -la            # List all files
> ncdu ~            # Analyze disk usage
> ranger            # File manager
```

### Network
```
> nmtui             # Network manager
> ip addr           # Network interfaces
> ping 8.8.8.8      # Test connectivity
```

### Development
```
> vim config.txt    # Edit file in vim
> git status        # Check git status
> npm install       # Install packages
```

## Requirements

- DankMaterialShell >= 0.1.0
- Terminal emulator (kitty, alacritty, foot, etc.)
- `wl-copy` (for clipboard support)
- Wayland compositor

## Compatibility

- **Compositors**: Niri and Hyprland
- **Distros**: Universal - works on any Linux distribution
- **Terminals**: Supports all major terminal emulators

## Technical Details

- **Type**: Launcher plugin
- **Trigger**: `>` (configurable)
- **Language**: QML (Qt Modeling Language)
- **Storage**: Command history stored in DMS settings

## Troubleshooting

### Commands not launching?
1. Verify terminal is configured in plugin settings
2. Check terminal is installed: `which kitty` (or your terminal)
3. Verify exec flag matches your terminal

### Terminal opens but command doesn't run?
- Ensure exec flag is correct for your terminal
- Most terminals use `-e`, but some (wezterm) use `start`

## Contributing

Found a bug or want to add features? Open an issue or submit a pull request!

### Regression checks

```bash
node --test tests/*.test.cjs
qmlformat CommandRunner.qml >/dev/null
```

The helper tests exercise actual shell commands with an isolated clipboard substitute. The Quickshell check loads the component with a settings stub and verifies persistent paste history, launcher refresh notifications, command/path suggestions without an extra keystroke, rapid query changes, and query clearing. Real compositor paste/focus behavior still needs an interactive check.

For an optional memory comparison against the pre-fix version, run `node tests/memory-benchmark.cjs 5c2cab4`. This creates a temporary 50,000-file tree and compares isolated Quickshell RSS; it does not scan your real home directory.

## License

MIT License - See LICENSE file for details

## Author

Created for the DankMaterialShell community

## Links

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Plugin Registry](https://github.com/AvengeMedia/dms-plugin-registry)
