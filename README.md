# jmux

A powerful tmux-based IDE combining ranger (file manager) and nvim (text editor) with integrated git workflow, buffer management, and persistent terminal sessions.

## Features

- **Dual-pane IDE** - Ranger file manager + Neovim editor with intelligent pane switching
- **Smart buffer management** - Recent files panel, buffer cycling, and persistent session state
- **Git integration** - Lazygit popup, interactive log viewer with commit breakdowns
- **Tabbed terminals** - 3 persistent terminal sessions with command palette navigation
- **Fuzzy finder** - Fast file search with preview using fzf
- **Configurable settings** - Themes, auto-switch behavior, file preview options
- **Bulletproof session cleanup** - Handles crashes and improper exits gracefully

## Installation

```bash
sudo ./install.sh
```

**Dependencies**: tmux, ranger, nvim, lazygit, fzf

**Optional**: git-delta (improved diff output in git log viewer)
```bash
brew install git-delta # macOS
sudo apt install git-delta # Debian/Ubuntu
```

## Usage

```bash
jmux                    # Start IDE in current directory  
jmux /path/to/project   # Start IDE in specific directory
```

## Keybindings

### File Navigation (Ranger)
- **`Enter`** - Open file in nvim (respects auto-switch setting)
- **`Tab`** - Toggle between ranger and nvim panes
- **`F1/F2`** - Alternative pane switching (ranger/nvim)
- **`Right Arrow`** - Directory navigation only (file opening disabled)
- **`Ctrl+P`** - Fuzzy file finder with preview popup
- **`Ctrl+R`** - Reload ranger configuration (for settings changes)

### Buffer Management (Nvim)
- **`Tab`** - Switch back to ranger pane
- **`F1/F2`** - Alternative pane switching
- **`Ctrl+N/M`** - Cycle through buffers (next/previous)
- **`]b/[b`** - Alternative buffer navigation
- **`Ctrl+B`** - Toggle recent files panel
- **`:q`** - Close buffer (or entire IDE if last buffer)

### Commands (Available in both panes)
- **`:g`** - Lazygit popup (90% overlay)
- **`:gl`** - Interactive git log with branch graph and commit previews
- **`:s`** - Settings menu (themes, auto-switch, hidden files, preview)
- **`:t`** - Tabbed terminal (3 persistent terminals with command palette)

### Tabbed Terminal Commands
- **`:`** - Command palette (q=quit, 1/2/3=switch tabs)
- **`Ctrl+B + 1/2/3`** - Direct tab switching
- **`Ctrl+B + Q`** - Return to jmux

### Git Log Viewer
- **`Enter`** - View detailed file breakdown for selected commit
- **`j/k`** - Navigate commits
- **`q`** - Close git log

## Settings & Configuration

### Settings Menu (`:s`)
Access comprehensive settings for:
- **Ranger Settings**: Toggle auto-switch to nvim, hidden files, file preview
- **Nvim Theme Selection**: Choose from available colorschemes
- **Apply settings immediately** without restart

### Custom Configuration
- **Pane ratios**: Edit `config.sh`
  - `RANGER_FOCUSED_RATIO=40` (default: 40% ranger, 60% nvim)
  - `NVIM_FOCUSED_RATIO=20` (default: 20% ranger, 80% nvim)

## Architecture

### Core Components
- **`jmux.sh`** - Main script with session lifecycle management
- **`lib/`** - Pure bash utility functions (27 functions, 55% test coverage)
- **`scripts/`** - tmux-dependent helper scripts for UI features
- **`tests/`** - Comprehensive test framework (87 assertions)
- **`analyze.sh`** - Self-analysis CLI for code quality monitoring

### Session Management
- **Bulletproof cleanup** - Handles ranger exits, crashes, and improper termination
- **Persistent terminals** - Terminal sessions survive jmux restarts
- **Smart key binding** - `:` command palette works across session reconnections

### Testing & Quality
```bash
bash analyze.sh test           # Run comprehensive test suite
bash analyze.sh report         # Full code quality analysis
bash analyze.sh coverage       # Test coverage report
bash analyze.sh function <name> # Analyze specific function complexity
```

## Development Workflow

- **iter** branch - Development/unstable features
- **dev** branch - Stable but not shippable  
- **main** branch - Production ready

## Troubleshooting

### Session Issues
- **Stuck in tmux session**: `bash cleanup_jmux_sessions.sh`
- **Settings not applying**: Press `Ctrl+R` in ranger to reload config
- **Terminal command palette not working**: Exit and re-enter with `:t`

### Performance
- **Slow fuzzy finder**: File cache is rebuilt automatically on directory changes
- **High complexity functions**: Use `bash analyze.sh function <name>` to identify

## Uninstall

```bash
~/.config/jmux/uninstall.sh
```