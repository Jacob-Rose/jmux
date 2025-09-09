#!/bin/bash
# Fast fuzzy file finder using pre-cached file list
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Determine current session ID
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
if [ -z "$CURRENT_SESSION" ] || ! [[ "$CURRENT_SESSION" =~ ^jmux- ]]; then
    echo "Error: Not running in a jmux session"
    exit 1
fi

# Use session-specific cached file list if available, otherwise fallback to find
SESSION_SUFFIX="${CURRENT_SESSION##*-}"
CACHE_FILE="/tmp/jmux_files_cache_${SESSION_SUFFIX}"

if [ -f "$CACHE_FILE" ]; then
    SELECTED=$(cat "$CACHE_FILE" | fzf --preview "cat {}" --height=100%)
else
    SELECTED=$(find . -type f -not -path '*/.*' | sed 's|^\./||' | fzf --preview "cat {}" --height=100%)
fi

if [ -n "$SELECTED" ]; then
    # Use the new file opening function to ensure it opens in main editor
    if tmux list-panes -t "$CURRENT_SESSION:dev" | grep -q "1:"; then
        tmux send-keys -t "$CURRENT_SESSION:dev.1" Escape ":lua open_file_in_main_editor('$(readlink -f "$SELECTED")')" Enter
        tmux select-window -t "$CURRENT_SESSION:dev"
        tmux select-pane -t 1
        tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%
    else
        tmux split-window -t "$CURRENT_SESSION:dev" -h -p 60 "cd '$SEARCH_DIR' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$SELECTED")'"
        tmux select-pane -t 1
        tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%
    fi
fi