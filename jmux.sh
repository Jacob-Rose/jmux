#!/bin/bash

# jmux: A tmux-based IDE with ranger and nvim
# Usage: jmux [directory]

# Set working directory (use argument or current directory)
WORK_DIR="${1:-$(pwd)}"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"  # Get absolute path

# Configuration paths
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"
RANGER_TEMP="$CONFIG_BASE/ranger_config"
NVIM_TEMP="$CONFIG_BASE/nvim_config"

# Create config directories
mkdir -p "$RANGER_TEMP" "$NVIM_TEMP"

# Ranger config
cat > "$RANGER_TEMP/rc.conf" <<'EOF'
# Hide preview panel
set preview_files false
set preview_directories false

# Open files with Enter key - use readlink to get absolute path
map <Enter> shell tmux send-keys -t 1 Escape ":e $(readlink -f %p)" Enter
unmap l
unmap q
# Disable right arrow from opening files - only allow directory navigation
map <right> eval fm.cd(fm.thisfile.path) if fm.thisfile.is_directory else None

# Switch between panes with Tab
map <TAB> shell tmux select-pane -t 1
map <S-TAB> shell tmux select-pane -t 0

# Open lazygit in popup with ;g
map ;g shell tmux display-popup -w 90%% -h 90%% -E lazygit
EOF

# Nvim config
cat > "$NVIM_TEMP/init.lua" <<'EOF'
-- Disable Ctrl+Q terminal control
vim.cmd('silent! unmap <C-q>')
vim.cmd('set t_ku=<Esc>[A')


-- Switch between panes with Tab
vim.keymap.set('n', '<Tab>', function()
  vim.fn.system("tmux select-pane -t 0")
end, { noremap = true, silent = true })
EOF

# Start tmux session with ranger in the first pane
tmux new-session -d -s ide "cd '$WORK_DIR' && ranger --confdir='$RANGER_TEMP'; tmux kill-session -t ide"
tmux rename-window 'dev'

# Split window - ranger gets 40%, nvim 60%
tmux split-window -h -p 60 "cd '$WORK_DIR' && nvim -u $NVIM_TEMP/init.lua; tmux kill-session -t ide"

# Focus on ranger pane initially
tmux select-pane -t 0

# Attach
tmux attach-session -t ide
