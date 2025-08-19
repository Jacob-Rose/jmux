#!/bin/bash
# Shared fuzzy file finder for jmux
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Run fzf and open selected file in nvim
SELECTED=$(fzf --preview "cat {}" --height=100%)
if [ -n "$SELECTED" ]; then
    # Check if nvim pane exists, create if not, then focus nvim with proper sizing
    if tmux list-panes | grep -q "1:"; then
        tmux send-keys -t 1 Escape ":e $(readlink -f "$SELECTED")" Enter
        tmux select-pane -t 1
        tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%
    else
        tmux split-window -h -p 60 "cd '$SEARCH_DIR' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$SELECTED")'"
        tmux select-pane -t 1
        tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%
    fi
fi