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
- `Enter` - Open file in nvim (creates pane if needed)
- `Ctrl+P` - Fuzzy file finder (VSCode-style)
- `Tab/Shift+Tab` - Switch between panes

**Buffer Management** (nvim)
- `Ctrl+N/M` - Cycle through buffers  
- `]b/[b` - Next/previous buffer
- `Ctrl+B` - Toggle recent files panel
- `:q` - Close buffer (or entire IDE if last buffer)

**Git Integration**
- `;g` - Lazygit popup (90% overlay, Esc to quit)
- `:gl` - Interactive git log with branch graph and commit previews

**Visual Features**
- Recent files panel with modification indicators (●)
- Dynamic nvim pane creation
- Mouse support throughout
- Compatible with nvim 0.6.1+

## Uninstall

```bash
~/.config/jmux/uninstall.sh
```