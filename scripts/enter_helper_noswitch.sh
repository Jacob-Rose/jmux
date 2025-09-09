#!/bin/bash

# No-switch enter helper for jmux
# Opens files in nvim but stays in ranger pane

# Source session utilities - try local copy first (portable mode)
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/jmux_session_utils.sh" ]; then
    source "$SCRIPT_DIR/jmux_session_utils.sh"
elif [ -f "$SCRIPT_DIR/../scripts/jmux_session_utils.sh" ]; then
    source "$SCRIPT_DIR/../scripts/jmux_session_utils.sh"
elif [ -f "/usr/local/bin/jmux-scripts/jmux_session_utils.sh" ]; then
    source "/usr/local/bin/jmux-scripts/jmux_session_utils.sh"
else
    echo "Error: Could not find jmux_session_utils.sh" >&2
    exit 1
fi

# No-switch enter command
if is_jmux_session && has_nvim_pane; then
    send_to_nvim Escape ":lua open_file_in_main_editor('$(readlink -f "$1")')" Enter
    # Stay in ranger - don't switch panes
else
    TARGET=$(get_jmux_target)
    if [ -n "$TARGET" ]; then
        tmux split-window -t "$TARGET" -h -p 60 "cd '$2' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$1")'"
        select_ranger_pane
    fi
fi