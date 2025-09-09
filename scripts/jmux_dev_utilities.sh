#!/bin/bash
# jmux Development Utilities
# Functions for detecting development vs production environment

# Check if we're running in development/portable mode (NOT from installed .config location)
is_dev() {
    local script_path="$(realpath "${BASH_SOURCE[1]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[1]:-$0}")"
    # We're in dev/portable mode if:
    # NOT running from .config/jmux (installed) or /usr/local/bin (system installed)
    # This covers any portable location: ~/jmux, /tmp/jmux, ~/Desktop/jmux, etc.
    if [[ "$script_path" == *"/.config/jmux/"* ]] || [[ "$script_path" == *"/usr/local/bin/"* ]]; then
        return 1  # Production/installed mode
    else
        return 0  # Development/portable mode
    fi
}

# Get the jmux project root directory (only works in dev/portable mode)
get_jmux_root() {
    if is_dev; then
        local script_path="$(realpath "${BASH_SOURCE[1]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[1]:-$0}")"
        # Find the directory containing jmux.sh (the project root)
        local current_dir="$(dirname "$script_path")"
        while [ "$current_dir" != "/" ]; do
            if [ -f "$current_dir/jmux.sh" ]; then
                echo "$current_dir"
                return 0
            fi
            current_dir="$(dirname "$current_dir")"
        done
        return 1
    else
        return 1
    fi
}

# Get appropriate temp/cache directory based on environment
get_temp_dir() {
    if is_dev; then
        echo "$(get_jmux_root)/tmp"
    else
        echo "/tmp/jmux"
    fi
}