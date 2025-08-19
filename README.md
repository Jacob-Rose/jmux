# jmux

A tmux-based IDE combining ranger (file manager) and nvim (text editor) with integrated git workflow and buffer management.

## Installation

```bash
sudo ./install.sh
```

**Dependencies**: tmux, ranger, nvim, lazygit, fzf

## Usage

```bash
jmux                    # Start IDE in current directory  
jmux /path/to/project   # Start IDE in specific directory
```

## Keybindings

**File Navigation**
- `Enter` - Open file in nvim with automatic pane resizing (20-80 split)
- `Right Arrow` - Directory navigation only (file opening disabled)
- `Ctrl+P` - Fuzzy file finder with preview popup
- `Tab` - Switch to nvim pane (20-80 split) 
- `Shift+Tab` - Switch to ranger pane (40-60 split)

**Buffer Management** (nvim)
- `Ctrl+N/M` - Cycle through buffers (next/previous)
- `]b/[b` - Alternative buffer navigation
- `Ctrl+B` - Toggle recent files panel
- `:q` - Close buffer (or entire IDE if last buffer)

**Git Integration**
- `;g` - Lazygit popup (90% overlay, Escape to quit)
- `:gl` - Interactive git log with branch graph and commit previews
- `Enter` (in git log) - View detailed file breakdown for selected commit

**Configuration**
- Customize pane ratios via `config.sh`
- RANGER_FOCUSED_RATIO=40 (default: 40% ranger, 60% nvim)
- NVIM_FOCUSED_RATIO=20 (default: 20% ranger, 80% nvim)

## Uninstall

```bash
~/.config/jmux/uninstall.sh
```