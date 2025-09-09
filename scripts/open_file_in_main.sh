#!/bin/bash
# Open file in main nvim editor, never in buffer list
# Usage: open_file_in_main.sh [filepath]

FILEPATH="$1"
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"

# Load session utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/jmux_session_utils.sh"

if [ -z "$FILEPATH" ]; then
    echo "Usage: $0 <filepath>"
    exit 1
fi

# Check if we're in a jmux session
if ! is_jmux_session; then
    echo "Error: Not running in a jmux session"
    exit 1
fi

# Send command to main nvim to open file in main editor window (not buffer list)
send_to_nvim "Escape" 
send_to_nvim ":lua open_file_in_main_editor('$(readlink -f "$FILEPATH")')" "Enter"

# Focus the main window and nvim pane
select_nvim_pane
tmux resize-pane -t 0 -x "$(get_nvim_ratio)%"