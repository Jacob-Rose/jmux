#!/bin/bash
# jmux Logging Utilities
# Generic logging functions for all jmux scripts

# Source development utilities for temp directory detection
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/jmux_dev_utilities.sh"

# Get log directory and ensure it exists
get_log_dir() {
    local log_dir="$(get_temp_dir)"
    mkdir -p "$log_dir" 2>/dev/null || true
    echo "$log_dir"
}

# Generic logging function
jmux_log() {
    local level="$1"
    local component="$2" 
    local message="$3"
    local log_dir="$(get_log_dir)"
    local log_file="$log_dir/${component}.log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file"
}

# Convenience logging functions
log_debug() { jmux_log "DEBUG" "$1" "$2"; }
log_info() { jmux_log "INFO" "$1" "$2"; }
log_warn() { jmux_log "WARN" "$1" "$2"; }
log_error() { jmux_log "ERROR" "$1" "$2"; }

# Clear logs for a component
clear_log() {
    local component="$1"
    local log_dir="$(get_log_dir)"
    local log_file="$log_dir/${component}.log"
    > "$log_file" 2>/dev/null || true
}