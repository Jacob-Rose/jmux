#!/bin/bash
# Fast fuzzy file finder using pre-cached file list
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Force tmux to refresh display for SSH
tmux refresh-client 2>/dev/null || true
sleep 0.1

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

# Load logging utilities
if ! command -v log_debug >/dev/null 2>&1; then
    SCRIPT_DIR="$(dirname "$0")"
    LOGGING_PATHS=(
        "$HOME/Documents/jmux/scripts/jmux_logging_utilities.sh"
        "$SCRIPT_DIR/jmux_logging_utilities.sh"
        "/usr/local/bin/jmux-scripts/jmux_logging_utilities.sh"
    )
    
    for LOGGING_PATH in "${LOGGING_PATHS[@]}"; do
        if [ -f "$LOGGING_PATH" ] && source "$LOGGING_PATH" 2>/dev/null; then
            break
        fi
    done
fi

# Clear previous logs and start logging
clear_log "fuzzy_finder" 2>/dev/null || true
log_debug "fuzzy_finder" "Starting fuzzy finder in directory: $SEARCH_DIR"

# Check if we're in a jmux session
if ! is_jmux_session; then
    log_error "fuzzy_finder" "Not running in a jmux session"
    echo "Error: Not running in a jmux session"
    exit 1
fi

# Get session info for cache file
SESSION=$(get_jmux_session)
SESSION_SUFFIX="${SESSION##*-}"
CACHE_FILE="/tmp/jmux_files_cache_${SESSION_SUFFIX}"

# Force terminal flush before fzf
stty sane 2>/dev/null || true

# Force unbuffered I/O for SSH
export TERM="${TERM:-xterm-256color}"
exec < /dev/tty

# Use session-specific cached file list if available, otherwise fallback to find
log_debug "fuzzy_finder" "About to start fzf"
if [ -f "$CACHE_FILE" ]; then
    log_debug "fuzzy_finder" "Using cached file list from: $CACHE_FILE"
    SELECTED=$(cat "$CACHE_FILE" | fzf --height=80)
else
    log_debug "fuzzy_finder" "Using find command to generate file list"
    SELECTED=$(find . -type f -not -path '*/.*' | sed 's|^\./||' | fzf --height=80)
fi
log_debug "fuzzy_finder" "fzf finished, selected file: $SELECTED"

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