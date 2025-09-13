#!/bin/bash
# jmux Logging Utilities
# Generic logging functions for all jmux scripts

# Get log directory and ensure it exists (self-contained)
get_log_dir() {
    local script_dir="$(dirname "${BASH_SOURCE[0]}")"
    local log_dir
    
    # Try to find jmux project root for development mode
    local current_dir="$(realpath "$script_dir" 2>/dev/null || echo "$script_dir")"
    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/jmux.sh" ]; then
            # Found jmux root - use development log location
            log_dir="$current_dir/tmp"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Fallback to system temp directory
    if [ -z "$log_dir" ]; then
        log_dir="/tmp/jmux"
    fi
    
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
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file" 2>/dev/null || true
}

# Log command execution with output capture
log_command() {
    local component="$1"
    local description="$2"
    shift 2
    local log_dir="$(get_log_dir)"
    local log_file="$log_dir/${component}.log"
    
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] $description: $*"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] Output:"
        "$@" 2>&1 | sed 's/^/    /'
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] Exit code: ${PIPESTATUS[0]}"
        echo "---"
    } >> "$log_file" 2>/dev/null || true
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

# Show logs for a component
show_log() {
    local component="$1"
    local lines="${2:-50}"
    local log_dir="$(get_log_dir)"
    local log_file="$log_dir/${component}.log"
    
    if [ -f "$log_file" ]; then
        echo "=== Last $lines lines from $component.log ==="
        tail -n "$lines" "$log_file"
        echo "=== End of $component.log ==="
    else
        echo "No log file found for component: $component"
    fi
}

# List all available log files
list_logs() {
    local log_dir="$(get_log_dir)"
    if [ -d "$log_dir" ]; then
        echo "Available log files in $log_dir:"
        ls -la "$log_dir"/*.log 2>/dev/null || echo "No log files found"
    else
        echo "Log directory not found: $log_dir"
    fi
}