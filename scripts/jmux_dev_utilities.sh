#!/bin/bash
# jmux Development Utilities
# Functions for detecting development vs production environment

# Check if we're running in development mode
is_dev() {
    local script_path="$(realpath "${BASH_SOURCE[1]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[1]:-$0}")"
    [[ "$script_path" == *"/Documents/jmux/"* ]]
}

# Get the jmux project root directory (only works in dev mode)
get_jmux_root() {
    if is_dev; then
        local script_path="$(realpath "${BASH_SOURCE[1]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[1]:-$0}")"
        echo "$script_path" | sed 's|/Documents/jmux/.*|/Documents/jmux|'
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