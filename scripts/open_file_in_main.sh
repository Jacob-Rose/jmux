#!/bin/bash
# Open file in main nvim editor, never in buffer list
# Usage: open_file_in_main.sh [filepath]

FILEPATH="$1"
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"

if [ -z "$FILEPATH" ]; then
    echo "Usage: $0 <filepath>"
    exit 1
fi

# Send command to main nvim to open file in main editor window (not buffer list)
tmux send-keys -t ide:dev.1 "Escape" 
tmux send-keys -t ide:dev.1 ":lua open_file_in_main_editor('$(readlink -f "$FILEPATH")')" Enter

# Focus the main dev window and main pane
tmux select-window -t ide:dev
tmux select-pane -t 1
tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%