# jmux

A tmux-based IDE that combines ranger (file manager) and nvim (text editor) in a split-pane interface with integrated git workflow.

## Features

- **Split Interface**: 40% ranger file manager, 60% nvim editor
- **Seamless File Opening**: Press Enter on files in ranger to open them in nvim
- **Git Integration**: Lazygit popup overlay for version control
- **Smart Navigation**: Tab switching between panes
- **Auto-cleanup**: Session terminates when either application exits

## Installation

```bash
sudo ./install.sh
```

**Dependencies**: tmux, ranger, nvim, lazygit

## Usage

```bash
jmux                    # Start IDE in current directory
jmux /path/to/project   # Start IDE in specific directory
```

## Keybindings

### Ranger (File Manager)
- `Enter` - Open file in nvim
- `Tab` - Switch to nvim pane
- `Shift+Tab` - Switch back to ranger pane
- `;g` - Open lazygit popup (90% screen overlay)
- `→` - Enter directories only (no file opening)

### Nvim (Editor)
- `Tab` - Switch to ranger pane
- `:q` - Quit nvim (closes entire IDE)

### Lazygit (Git Interface)
- `q` - Close lazygit popup
- Standard lazygit keybindings apply

## Uninstall

```bash
~/.config/jmux/uninstall.sh
```