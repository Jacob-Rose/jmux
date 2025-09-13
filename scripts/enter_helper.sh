#!/bin/bash

# Auto-switch enter helper for jmux
# Opens files in nvim and switches to nvim pane

# Source utilities - try local copy first (portable mode)
SCRIPT_DIR="$(dirname "$0")"

# Load logging utilities with fallback
LOGGING_LOADED=false
if [ -f "$SCRIPT_DIR/jmux_logging_utilities.sh" ]; then
    . "$SCRIPT_DIR/jmux_logging_utilities.sh" && LOGGING_LOADED=true
elif [ -f "$SCRIPT_DIR/../scripts/jmux_logging_utilities.sh" ]; then
    . "$SCRIPT_DIR/../scripts/jmux_logging_utilities.sh" && LOGGING_LOADED=true
elif [ -f "/usr/local/bin/jmux-scripts/jmux_logging_utilities.sh" ]; then
    . "/usr/local/bin/jmux-scripts/jmux_logging_utilities.sh" && LOGGING_LOADED=true
fi

# Create fallback logging functions if loading failed
if [ "$LOGGING_LOADED" = "false" ]; then
    log_info() { echo "[INFO] $2" >&2; }
    log_error() { echo "[ERROR] $2" >&2; }
    log_command() { shift 2; echo "[CMD] $*" >&2; "$@"; }
fi

# Source session utilities
if [ -f "$SCRIPT_DIR/jmux_session_utils.sh" ]; then
    . "$SCRIPT_DIR/jmux_session_utils.sh"
elif [ -f "$SCRIPT_DIR/../scripts/jmux_session_utils.sh" ]; then
    . "$SCRIPT_DIR/../scripts/jmux_session_utils.sh"
elif [ -f "/usr/local/bin/jmux-scripts/jmux_session_utils.sh" ]; then
    . "/usr/local/bin/jmux-scripts/jmux_session_utils.sh"
else
    echo "Error: Could not find jmux_session_utils.sh" >&2
    exit 1
fi

# Auto-switch enter command
log_info "enter_helper" "Opening file: $1 in directory: $2"

if is_jmux_session && has_nvim_pane; then
    log_info "enter_helper" "Nvim pane exists, sending file to existing nvim"
    send_to_nvim Escape ":lua open_file_in_main_editor('$(readlink -f "$1")')" Enter
    select_nvim_pane
    NVIM_RATIO="$(get_nvim_ratio)"
    log_info "enter_helper" "Resizing ranger pane to ${NVIM_RATIO}%"
    log_command "enter_helper" "Resize ranger pane" tmux resize-pane -t 0 -x "${NVIM_RATIO}%"
else
    TARGET=$(get_jmux_target)
    log_info "enter_helper" "No nvim pane, creating new split. Target: $TARGET"
    if [ -n "$TARGET" ]; then
        log_command "enter_helper" "Create nvim split" tmux split-window -t "$TARGET" -h "cd '$2' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$1")'"
        select_nvim_pane
        NVIM_RATIO="$(get_nvim_ratio)"
        log_info "enter_helper" "Resizing ranger pane to ${NVIM_RATIO}%"
        log_command "enter_helper" "Resize ranger pane" tmux resize-pane -t 0 -x "${NVIM_RATIO}%"
    else
        log_error "enter_helper" "No jmux target found"
    fi
fi