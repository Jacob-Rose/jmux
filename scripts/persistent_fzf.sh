#!/bin/bash
# Access persistent fzf instance for jmux
# Usage: persistent_fzf.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"

# Show the persistent fzf window
tmux display-popup -w 80% -h 60% -E "tmux attach-session -t ide:fzf-finder"

# After popup closes, check if a file was selected
if [ -f "/tmp/jmux_fzf_output" ]; then
    SELECTED=$(tail -1 /tmp/jmux_fzf_output 2>/dev/null)
    # Clear the output file
    > /tmp/jmux_fzf_output
    
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
fi