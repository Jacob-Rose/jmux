#!/bin/bash

# External command interface for jmux
# Allows external programs to send commands to ranger and nvim panes

# Source utilities
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/jmux_session_utils.sh" ]; then
    . "$SCRIPT_DIR/jmux_session_utils.sh"
elif [ -f "$SCRIPT_DIR/../scripts/jmux_session_utils.sh" ]; then
    . "$SCRIPT_DIR/../scripts/jmux_session_utils.sh"
fi

# Load logging utilities
if [ -f "$SCRIPT_DIR/jmux_logging_utilities.sh" ]; then
    . "$SCRIPT_DIR/jmux_logging_utilities.sh"
elif [ -f "$SCRIPT_DIR/../scripts/jmux_logging_utilities.sh" ]; then
    . "$SCRIPT_DIR/../scripts/jmux_logging_utilities.sh"
fi

# Command routing functions
send_to_ranger() {
    local command="$1"
    log_info "external_command" "Sending to ranger: $command"
    # Call the function from jmux_session_utils.sh
    send_to_ranger "$command"
}

send_to_nvim() {
    local command="$1"
    log_info "external_command" "Sending to nvim: $command"
    # Call the function from jmux_session_utils.sh
    send_to_nvim "$command"
}

# File operations
open_file_in_ranger() {
    local file_path="$1"
    local full_path=$(readlink -f "$file_path")

    log_info "external_command" "Opening file in ranger: $full_path"

    # Navigate to file directory and select file
    local dir_path=$(dirname "$full_path")
    local file_name=$(basename "$full_path")

    # Send commands to ranger to navigate and select
    send_to_ranger "cd '$dir_path'"
    send_to_ranger "search '$file_name'"
    send_to_ranger "move down"
}

open_file_in_nvim() {
    local file_path="$1"
    local full_path=$(readlink -f "$file_path")

    log_info "external_command" "Opening file in nvim: $full_path"

    # Use the buffer manager to open file
    send_to_nvim "Escape"
    send_to_nvim ":lua open_file_in_main_editor('$full_path')"
    send_to_nvim "Enter"
}

# Pane operations
switch_to_ranger() {
    log_info "external_command" "Switching to ranger pane"
    select_ranger_pane
}

switch_to_nvim() {
    log_info "external_command" "Switching to nvim pane"
    select_nvim_pane
}

# Session information
get_session_info() {
    local session_name=$(get_jmux_session)
    local window_name=$(get_jmux_window)
    local target=$(get_jmux_target)
    local has_nvim=$(has_nvim_pane && echo "yes" || echo "no")
    
    echo "Session: $session_name"
    echo "Window: $window_name"
    echo "Target: $target"
    echo "Has nvim pane: $has_nvim"
}

# Allow overriding session for external use
if [ -n "$JMUX_TEST_SESSION" ]; then
    # Override the session detection functions
    get_jmux_session() {
        echo "$JMUX_TEST_SESSION"
    }
    
    # Override the functions that send commands to tmux
    send_to_ranger() {
        local command="$1"
        # In test mode, just log and succeed
        return 0
    }
    
    send_to_nvim() {
        local command="$1"
        # In test mode, just log and succeed
        return 0
    }
fi

# Main command dispatcher
case "${1:-help}" in
    "ranger")
        shift
        send_to_ranger "$*"
        ;;
    "nvim")
        shift
        send_to_nvim "$*"
        ;;
    "open-file-ranger")
        open_file_in_ranger "$2"
        ;;
    "open-file-nvim")
        open_file_in_nvim "$2"
        ;;
    "switch-ranger")
        switch_to_ranger
        ;;
    "switch-nvim")
        switch_to_nvim
        ;;
    "session-info")
        get_session_info
        ;;
    "help"|*)
        echo "jmux External Command Interface"
        echo ""
        echo "Usage: $0 <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  ranger <command>        Send command to ranger pane"
        echo "  nvim <command>          Send command to nvim pane"
        echo "  open-file-ranger <file> Open file in ranger (navigate to it)"
        echo "  open-file-nvim <file>   Open file in nvim editor"
        echo "  switch-ranger           Switch to ranger pane"
        echo "  switch-nvim             Switch to nvim pane"
        echo "  session-info            Show current session information"
        echo "  help                    Show this help"
        ;;
esac