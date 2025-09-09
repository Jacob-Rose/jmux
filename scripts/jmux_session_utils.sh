#!/bin/bash

# jmux Session Utilities
# Helper functions for getting current jmux session and window information
# Source this file in other scripts: source "$(dirname "$0")/jmux_session_utils.sh"

# Cache for session info to avoid repeated tmux calls
_JMUX_SESSION_CACHE=""
_JMUX_WINDOW_CACHE=""
_JMUX_TARGET_CACHE=""
_JMUX_HAS_NVIM_CACHE=""

# Get all jmux session info in one tmux call
_refresh_jmux_cache() {
    local session_info
    session_info=$(tmux display-message -p '#S' 2>/dev/null)
    
    # Check if valid jmux session (only check for new format)
    if [[ "$session_info" =~ ^jmux- ]]; then
        
        _JMUX_SESSION_CACHE="$session_info"
        
        # Get window and pane info in one call
        local window_pane_info
        window_pane_info=$(tmux list-windows -t "$session_info" 2>/dev/null | head -1)
        
        if [ -n "$window_pane_info" ]; then
            # Extract window name
            local window=$(echo "$window_pane_info" | cut -d: -f2 | cut -d'*' -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            _JMUX_WINDOW_CACHE="$window"
            _JMUX_TARGET_CACHE="$session_info:$window"
            
            # Check if nvim pane exists
            if tmux list-panes -t "$_JMUX_TARGET_CACHE" 2>/dev/null | grep -q "1:"; then
                _JMUX_HAS_NVIM_CACHE="yes"
            else
                _JMUX_HAS_NVIM_CACHE="no"
            fi
        else
            _JMUX_WINDOW_CACHE=""
            _JMUX_TARGET_CACHE=""
            _JMUX_HAS_NVIM_CACHE="no"
        fi
    else
        # Not a jmux session
        _JMUX_SESSION_CACHE=""
        _JMUX_WINDOW_CACHE=""
        _JMUX_TARGET_CACHE=""
        _JMUX_HAS_NVIM_CACHE="no"
    fi
}

# Get the current jmux session ID
get_jmux_session() {
    [ -z "$_JMUX_SESSION_CACHE" ] && _refresh_jmux_cache
    if [ -n "$_JMUX_SESSION_CACHE" ]; then
        echo "$_JMUX_SESSION_CACHE"
        return 0
    fi
    return 1
}

# Get the current jmux main window name
get_jmux_window() {
    [ -z "$_JMUX_WINDOW_CACHE" ] && _refresh_jmux_cache
    if [ -n "$_JMUX_WINDOW_CACHE" ]; then
        echo "$_JMUX_WINDOW_CACHE"
        return 0
    fi
    return 1
}

# Get the full session:window identifier for jmux
get_jmux_target() {
    [ -z "$_JMUX_TARGET_CACHE" ] && _refresh_jmux_cache
    if [ -n "$_JMUX_TARGET_CACHE" ]; then
        echo "$_JMUX_TARGET_CACHE"
        return 0
    fi
    return 1
}

# Check if we're currently in a jmux session
is_jmux_session() {
    get_jmux_session >/dev/null 2>&1
    return $?
}

# Send keys to ranger pane (pane 0)
send_to_ranger() {
    local target=$(get_jmux_target)
    if [ -n "$target" ]; then
        tmux send-keys -t "$target.0" "$@"
        return $?
    fi
    return 1
}

# Send keys to nvim pane (pane 1)
send_to_nvim() {
    local target=$(get_jmux_target)
    if [ -n "$target" ]; then
        tmux send-keys -t "$target.1" "$@"
        return $?
    fi
    return 1
}

# Select the jmux main window
select_jmux_window() {
    local target=$(get_jmux_target)
    if [ -n "$target" ]; then
        tmux select-window -t "$target"
        return $?
    fi
    return 1
}

# Select ranger pane
select_ranger_pane() {
    local target=$(get_jmux_target)
    if [ -n "$target" ]; then
        tmux select-window -t "$target"
        tmux select-pane -t 0
        return $?
    fi
    return 1
}

# Select nvim pane
select_nvim_pane() {
    local target=$(get_jmux_target)
    if [ -n "$target" ]; then
        tmux select-window -t "$target"
        tmux select-pane -t 1
        return $?
    fi
    return 1
}

# Check if nvim pane exists
has_nvim_pane() {
    [ -z "$_JMUX_HAS_NVIM_CACHE" ] && _refresh_jmux_cache
    [ "$_JMUX_HAS_NVIM_CACHE" = "yes" ]
    return $?
}

# Get environment-appropriate focused ratios
get_ranger_ratio() {
    echo "${RANGER_FOCUSED_RATIO:-40}"
}

get_nvim_ratio() {
    echo "${NVIM_FOCUSED_RATIO:-20}"
}

# Example usage function (for testing/documentation)
print_jmux_info() {
    echo "=== jmux Session Info ==="
    echo "Session: $(get_jmux_session || echo 'Not found')"
    echo "Window: $(get_jmux_window || echo 'Not found')"
    echo "Target: $(get_jmux_target || echo 'Not found')"
    echo "Is jmux session: $(is_jmux_session && echo 'Yes' || echo 'No')"
    echo "Has nvim pane: $(has_nvim_pane && echo 'Yes' || echo 'No')"
    echo "========================="
}

# If script is run directly, show info
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    print_jmux_info
fi