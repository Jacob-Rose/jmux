#!/bin/bash

# jmux Log Viewer
# Quick script to view jmux logs

SCRIPT_DIR="$(dirname "$0")"

# Load logging utilities
if [ -f "$SCRIPT_DIR/jmux_logging_utilities.sh" ]; then
    source "$SCRIPT_DIR/jmux_logging_utilities.sh"
elif [ -f "$SCRIPT_DIR/../scripts/jmux_logging_utilities.sh" ]; then
    source "$SCRIPT_DIR/../scripts/jmux_logging_utilities.sh"
else
    echo "Error: Could not find jmux_logging_utilities.sh"
    exit 1
fi

case "${1:-list}" in
    "list")
        list_logs
        echo ""
        echo "Also checking system temp logs..."
        if [ -d "/tmp/jmux" ]; then
            echo "Available log files in /tmp/jmux:"
            ls -la "/tmp/jmux"/*.log 2>/dev/null || echo "No log files found in /tmp/jmux"
        fi
        ;;
    "clear")
        if [ -n "$2" ]; then
            clear_log "$2"
            # Also clear from system temp if it exists
            rm -f "/tmp/jmux/$2.log" 2>/dev/null
            echo "Cleared log for component: $2"
        else
            echo "Usage: $0 clear <component>"
            echo "Available components: jmux, enter_helper, enter_helper_noswitch"
        fi
        ;;
    *)
        show_log "$1" "${2:-50}"
        # Also check system temp location if local log doesn't exist
        local log_dir="$(get_log_dir)"
        local log_file="$log_dir/$1.log"
        if [ ! -f "$log_file" ] && [ -f "/tmp/jmux/$1.log" ]; then
            echo ""
            echo "=== Found log in system temp location ==="
            tail -n "${2:-50}" "/tmp/jmux/$1.log"
            echo "=== End of $1.log (from /tmp/jmux) ==="
        fi
        ;;
esac