#!/bin/bash
# Fast fuzzy file finder using pre-cached file list
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Use cached file list if available, otherwise fallback to find
if [ -f "/tmp/jmux_files_cache" ]; then
    SELECTED=$(cat /tmp/jmux_files_cache | fzf --preview "cat {}" --height=100%)
else
    SELECTED=$(find . -type f -not -path '*/.*' | sed 's|^\./||' | fzf --preview "cat {}" --height=100%)
fi

if [ -n "$SELECTED" ]; then
    # Use the new file opening function to ensure it opens in main editor
    if tmux list-panes -t ide:dev | grep -q "1:"; then
        tmux send-keys -t ide:dev.1 Escape ":lua open_file_in_main_editor('$(readlink -f "$SELECTED")')" Enter
        tmux select-window -t ide:dev
        tmux select-pane -t 1
        tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%
    else
        tmux split-window -t ide:dev -h -p 60 "cd '$SEARCH_DIR' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$SELECTED")'"
        tmux select-pane -t 1
        tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%
    fi
fi