#!/bin/bash
# Fast fuzzy file finder using pre-cached file list
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Load session utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/jmux_session_utils.sh"

# Check if we're in a jmux session
if ! is_jmux_session; then
    echo "Error: Not running in a jmux session"
    exit 1
fi

# Get session info for cache file
SESSION=$(get_jmux_session)
SESSION_SUFFIX="${SESSION##*-}"
CACHE_FILE="/tmp/jmux_files_cache_${SESSION_SUFFIX}"

# Use session-specific cached file list if available, otherwise fallback to find
if [ -f "$CACHE_FILE" ]; then
    SELECTED=$(cat "$CACHE_FILE" | fzf --preview "cat {}" --height=100%)
else
    SELECTED=$(find . -type f -not -path '*/.*' | sed 's|^\./||' | fzf --preview "cat {}" --height=100%)
fi

if [ -n "$SELECTED" ]; then
    # Use the new file opening function to ensure it opens in main editor
    if has_nvim_pane; then
        send_to_nvim Escape ":lua open_file_in_main_editor('$(readlink -f "$SELECTED")')" Enter
        select_nvim_pane
        tmux resize-pane -t 0 -x "$(get_nvim_ratio)%"
    else
        TARGET=$(get_jmux_target)
        if [ -n "$TARGET" ]; then
            tmux split-window -t "$TARGET" -h -p 60 "cd '$SEARCH_DIR' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$SELECTED")'"
            select_nvim_pane
            tmux resize-pane -t 0 -x "$(get_nvim_ratio)%"
        fi
    fi
fi