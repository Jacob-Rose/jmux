#!/bin/bash

# jmux Session Utilities
# Helper functions for getting current jmux session and window information
# Source this file in other scripts: source "$(dirname "$0")/jmux_session_utils.sh"

# Get the current jmux session ID
get_jmux_session() {
    local session=$(tmux display-message -p '#S' 2>/dev/null)
    if [[ "$session" =~ ^jmux- ]]; then
        echo "$session"
        return 0
    else
        # Fallback for legacy sessions
        if tmux has-session -t "ide" 2>/dev/null; then
            echo "ide"
            return 0
        fi
        return 1
    fi
}

# Get the current jmux main window name (the one with ranger/nvim)
get_jmux_window() {
    local session=$(get_jmux_session)
    if [ -z "$session" ]; then
        return 1
    fi
    
    # Find the window that contains "jmux -" (main development window)
    local window=$(tmux list-windows -t "$session" 2>/dev/null | grep "jmux -" | head -1 | cut -d: -f2 | cut -d'*' -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -n "$window" ]; then
        echo "$window"
        return 0
    fi
    
    # Fallback: get the first window  
    window=$(tmux list-windows -t "$session" 2>/dev/null | head -1 | cut -d: -f2 | cut -d'*' -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -n "$window" ]; then
        echo "$window"
        return 0
    fi
    
    return 1
}

# Get the full session:window identifier for jmux
get_jmux_target() {
    local session=$(get_jmux_session)
    local window=$(get_jmux_window)
    
    if [ -n "$session" ] && [ -n "$window" ]; then
        echo "$session:$window"
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
    local target=$(get_jmux_target)
    if [ -n "$target" ]; then
        tmux list-panes -t "$target" 2>/dev/null | grep -q "1:"
        return $?
    fi
    return 1
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