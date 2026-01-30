# AGENTS.md - DMS Command Runner

## Project Overview
A DankMaterialShell (DMS) launcher plugin for executing shell commands directly from the launcher with history tracking and preset shortcuts.

**Language**: QML (Qt Modeling Language)
**Type**: Launcher plugin for DankMaterialShell
**Default Trigger**: `>`
**Version**: 1.1.2

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  User Input                                          │
│  "> htop"                                           │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  Command Processing                                  │
│  - Parse command                                     │
│  - Check history for suggestions                    │
│  - Generate action items:                           │
│    • Run in terminal                                │
│    • Run in background                              │
│    • Copy to clipboard                              │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  Execution Methods                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Terminal   │  │  Background  │  │ Clipboard │ │
│  │              │  │              │  │           │ │
│  │ terminal -e  │  │  sh -c cmd   │  │ wl-copy   │ │
│  │  + wrapper   │  │   (detached) │  │           │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  History Tracking                                    │
│  - Add to history (most recent first)               │
│  - Limit to maxHistoryItems                         │
│  - Persist to DMS settings                          │
└─────────────────────────────────────────────────────┘
```

## File Structure

### Core Files
- **plugin.json** - Plugin metadata, version, trigger, capabilities
- **CommandRunner.qml** - Main component (~165 lines)
  - Command parsing and execution
  - History management
  - Terminal/background/clipboard actions
- **CommandRunnerSettings.qml** - Settings UI (~200 lines)
  - Terminal configuration
  - History management
  - Trigger configuration

## Key Concepts

### Execution Modes

#### 1. Terminal Execution (Default)
Runs command in user's configured terminal with a wrapper:
```javascript
const wrappedCommand = command + "; echo '\nPress Enter to close...'; read";
Quickshell.execDetached([terminal.cmd, terminal.execFlag, "sh", "-c", wrappedCommand]);
```

**Wrapper purpose**:
- Keeps terminal open after command completes
- Prevents terminal from closing immediately
- Allows user to review output

#### 2. Background Execution
Runs command silently without opening terminal:
```javascript
Quickshell.execDetached(["sh", "-c", command]);
```

**Use cases**: Fire-and-forget commands, system services, background tasks

#### 3. Clipboard Copy
Copies command to clipboard using wl-copy:
```javascript
Quickshell.execDetached(["sh", "-c", "echo -n '" + text + "' | wl-copy"]);
```

### History Management

**Storage**: DMS plugin settings (`commandRunner.history`)
**Max items**: Configurable (1-100, default 20)
**Order**: Most recent first (LIFO)

**Deduplication**: When command is re-executed, it's moved to top:
```javascript
function addToHistory(command) {
    const index = commandHistory.indexOf(command);
    if (index > -1) {
        commandHistory.splice(index, 1);  // Remove old entry
    }
    commandHistory.unshift(command);       // Add to front
    // Trim to max size
    if (commandHistory.length > maxHistoryItems) {
        commandHistory = commandHistory.slice(0, maxHistoryItems);
    }
}
```

### Terminal Configuration

Users must configure their terminal before first use:

**Common configurations**:
- `kitty` with `-e` flag
- `alacritty` with `-e` flag
- `foot` with `-e` flag
- `wezterm` with `start` flag
- `gnome-terminal` with `--` flag

**Storage**:
- `commandRunner.terminal` - Terminal command (e.g., "kitty")
- `commandRunner.execFlag` - Execution flag (e.g., "-e")

## Development Workflow

### 1. Modifying Command Execution

**Location**: `CommandRunner.qml` lines 102-114

**Terminal execution** (runCommand):
- Wraps command with pause/read
- Launches in configured terminal
- Adds to history

**Background execution** (runBackground):
- No terminal, direct shell execution
- Adds to history

**Security consideration**: Commands are passed to `sh -c`, which can execute arbitrary code. This is intentional but means:
- No validation/sanitization
- Full shell features available (pipes, redirects, etc.)
- User responsibility for command safety

### 2. Adding Common Command Shortcuts

**Location**: `CommandRunnerSettings.qml`

The settings UI includes a list of common commands that appear when no query is entered. To add more:

1. These are generated dynamically from history
2. Or could be hardcoded in `getItems()` when query is empty
3. Consider adding a "favorites" feature for pinned commands

### 3. Customizing History Behavior

**Location**: `CommandRunner.qml` lines 139-156

Options to customize:
- Change max history items (currently 20)
- Add history search/filtering
- Implement history categories
- Add timestamp tracking
- Export/import history

### 4. Testing Changes

**After modifying CommandRunner.qml:**
1. Save changes
2. Restart DMS
3. Test with `> [command]` in launcher
4. Verify:
   - Terminal opens for "Run: command"
   - Background execution works silently
   - Clipboard copy works
   - History tracking works
   - Toast notifications appear

**Testing checklist**:
- [ ] Terminal execution opens terminal
- [ ] Command runs and terminal stays open
- [ ] Background execution runs silently
- [ ] Clipboard copy works (test with paste)
- [ ] History updates correctly
- [ ] History suggestions filter by query
- [ ] Settings persist across restarts

## Common Tasks

### Add terminal support for new emulator
1. Document in README.md's terminal table
2. Users configure via Settings UI
3. No code changes needed (terminal is configurable)

### Change history size default
**Location**: `CommandRunner.qml` line 12
```javascript
property int maxHistoryItems: 20  // Change this
```

### Modify terminal wrapper
**Location**: `CommandRunner.qml` line 105
```javascript
const wrappedCommand = command + "; echo '\nPress Enter to close...'; read";
```

**Alternatives**:
- `; exec $SHELL` - Keep terminal open in shell
- `; sleep 5` - Auto-close after delay
- Remove wrapper - Terminal closes immediately

### Implement command validation
Add before execution:
```javascript
function runCommand(command) {
    // Validate command exists
    if (!isCommandValid(command)) {
        showToast("Command not found: " + command);
        return;
    }
    // ... rest of execution
}
```

### Add command favorites
1. Add `favorites` property and settings storage
2. Add "star" action to `getItems()`
3. Show favorites at top of results
4. Persist to settings

## Important QML Details

### Settings Persistence
**Location**: Lines 16-22, 158-163

Settings are loaded/saved via `pluginService`:
```javascript
Component.onCompleted: {
    trigger = pluginService.loadPluginData("commandRunner", "trigger", ">");
    commandHistory = pluginService.loadPluginData("commandRunner", "history", []);
    maxHistoryItems = pluginService.loadPluginData("commandRunner", "maxHistoryItems", 20);
}
```

History auto-saves when updated:
```javascript
if (pluginService) {
    pluginService.savePluginData("commandRunner", "history", commandHistory);
}
```

### Terminal Detection
**Location**: Lines 122-137

Falls back to `kitty` with `-e` if no configuration:
```javascript
function getTerminalCommand() {
    // Try to load from settings
    const terminal = pluginService.loadPluginData("commandRunner", "terminal", "kitty");
    const execFlag = pluginService.loadPluginData("commandRunner", "execFlag", "-e");
    // Return configured or default
    return { cmd: terminal, execFlag: execFlag };
}
```

### Action Parsing
**Location**: Lines 73-95

Actions are encoded as `type:command`:
- `run:htop` - Run in terminal
- `background:systemctl restart service` - Run in background
- `copy:git status` - Copy to clipboard

Parsed via:
```javascript
const actionParts = item.action.split(":");
const actionType = actionParts[0];
const command = actionParts.slice(1).join(":");  // Rejoin in case command has ":"
```

## Troubleshooting

### Terminal doesn't open
1. Check terminal is installed: `which kitty`
2. Verify terminal setting in plugin config
3. Test terminal manually: `kitty -e echo test`

### Terminal opens but command doesn't run
1. Verify exec flag matches terminal
2. Test: `kitty -e sh -c "echo test; read"`
3. Check terminal documentation for correct flag

### Commands not appearing in history
1. Verify `pluginService` is available
2. Check settings storage: DMS settings file
3. Verify `maxHistoryItems` > 0

### Clipboard copy fails
1. Check `wl-copy` installed: `which wl-copy`
2. Install wl-clipboard package
3. Test manually: `echo test | wl-copy`

### Background execution seems broken
- Background commands don't show output
- Check terminal for errors: `journalctl -f`
- Verify command actually ran (check side effects)

## Configuration

### plugin.json
- **id**: `commandRunner`
- **trigger**: `>` (configurable by user)
- **type**: `launcher`
- **capabilities**: `["command-execution", "shell"]`

### Settings Storage Keys
- `commandRunner.trigger` - Trigger character/string
- `commandRunner.terminal` - Terminal emulator command
- `commandRunner.execFlag` - Terminal execution flag
- `commandRunner.history` - Array of command strings
- `commandRunner.maxHistoryItems` - Max history size (1-100)

## Security Considerations

### Command Injection
Commands are executed via `sh -c` with **no sanitization**:
```javascript
Quickshell.execDetached(["sh", "-c", command]);
```

**This is intentional** to allow:
- Shell features (pipes, redirects, variables)
- Complex command chains
- Full shell scripting

**User responsibility**:
- Don't run untrusted commands
- Review before executing
- Understand shell metacharacters

### Privilege Escalation
Commands run with user's privileges. No sudo/doas handling:
- Users must include `sudo` in command if needed
- No password prompting in GUI
- Terminal handles authentication

## Version Bumping

**Location**: `plugin.json` line 5

**Versioning scheme**: Semantic versioning
- Patch (1.1.x): Bug fixes, minor improvements
- Minor (1.x.0): New features, UI enhancements
- Major (x.0.0): Breaking changes, architecture changes

## Dependencies

**Runtime**:
- DankMaterialShell >= 0.1.0
- Terminal emulator (kitty, alacritty, foot, etc.)
- wl-copy (wl-clipboard package) - for clipboard support
- Wayland compositor

**Build**: None (pure QML, no build process)

## Git Workflow

### Commit Message Format
Use conventional commits:
- `feat:` - New features, execution modes
- `fix:` - Bug fixes, terminal compatibility
- `docs:` - Documentation updates
- `refactor:` - Code improvements

### Example Commits
```bash
# Add new feature
git commit -m "feat: add command favorites/pinning

Allows users to pin frequently used commands
to the top of results list."

# Fix terminal issue
git commit -m "fix: support terminals with non-standard exec flags

Adds support for wezterm's 'start' flag and
gnome-terminal's '--' flag."
```

## Future Enhancement Ideas

- **Command favorites/pinning** - Star commands to keep at top
- **Command templates** - Parameterized commands with placeholders
- **Command categories** - Group commands by type (system, dev, network)
- **Command aliases** - Short names for long commands
- **Multi-command sequences** - Chain multiple commands
- **Working directory** - Set CWD for command execution
- **Environment variables** - Pass custom env vars
- **Output capture** - Show command output in launcher
- **Command validation** - Check if command exists before running
- **Sudo integration** - Handle password prompts
- **Command scheduling** - Run at specific time/interval

## Testing Checklist

- [ ] Terminal execution works with common terminals
- [ ] Background execution runs silently
- [ ] Clipboard copy works
- [ ] History tracking works
- [ ] History filters by query
- [ ] Settings persist across restarts
- [ ] Toast notifications appear
- [ ] Trigger configuration works
- [ ] Max history items setting works
- [ ] History clear function works

## Common Command Examples

### System Monitoring
- `htop`, `btop`, `top` - Process monitors
- `journalctl -f` - Live system logs
- `df -h`, `free -h` - Disk/memory usage

### File Operations
- `ranger`, `lf` - File managers
- `ncdu` - Disk usage analyzer
- `fzf` - Fuzzy file finder

### Network
- `nmtui` - Network manager TUI
- `ping 8.8.8.8` - Network test
- `ip addr` - Network interfaces

### Development
- `vim`, `nvim` - Editors
- `git status` - Git operations
- `npm install`, `cargo build` - Build commands

## Resources

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Plugin Registry](https://github.com/AvengeMedia/dms-plugin-registry)
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard)

---

**Last Updated**: 2026-01-30
**Maintainer**: devnullvoid
**AI-Friendly**: This document helps AI agents quickly understand and work with this plugin.
