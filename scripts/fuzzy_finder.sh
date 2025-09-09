#!/bin/bash
# Fast fuzzy file finder using pre-cached file list
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Fast path-cached sourcing of session utils
UTILS_CACHE_FILE="/tmp/jmux_utils_path_$$"

# Skip sourcing if functions already exist
if ! command -v get_jmux_session >/dev/null 2>&1; then
    # Try cached path first
    if [ -f "$UTILS_CACHE_FILE" ]; then
        CACHED_PATH="$(cat "$UTILS_CACHE_FILE")"
        if [ -f "$CACHED_PATH" ] && source "$CACHED_PATH" 2>/dev/null; then
            # Cache hit - sourced successfully
            :
        else
            # Cache miss - remove stale cache
            rm -f "$UTILS_CACHE_FILE"
        fi
    fi
    
    # If still not loaded, do full search and cache result
    if ! command -v get_jmux_session >/dev/null 2>&1; then
        SCRIPT_DIR="$(dirname "$0")"
        POSSIBLE_PATHS=(
            "/usr/local/bin/jmux-scripts/jmux_session_utils.sh"
            "$HOME/Documents/jmux/scripts/jmux_session_utils.sh"
            "$SCRIPT_DIR/jmux_session_utils.sh"
        )
        
        for UTILS_PATH in "${POSSIBLE_PATHS[@]}"; do
            if [ -f "$UTILS_PATH" ] && source "$UTILS_PATH" 2>/dev/null; then
                # Cache the successful path
                echo "$UTILS_PATH" > "$UTILS_CACHE_FILE"
                break
            fi
        done
        
        # Verify sourcing worked
        command -v get_jmux_session >/dev/null 2>&1 || { echo "Error: Could not find jmux_session_utils.sh" >&2; exit 1; }
    fi
fi

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
    SELECTED=$(cat "$CACHE_FILE" | fzf --preview "cat {}" --height=40 --reverse --border)
else
    SELECTED=$(find . -type f -not -path '*/.*' | sed 's|^\./||' | fzf --preview "cat {}" --height=40 --reverse --border)
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