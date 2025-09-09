#!/bin/bash

# Session Manager for jmux
# Handles session metadata, listing, killing, and attaching

SESSIONS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jmux/sessions"

# Ensure sessions directory exists
mkdir -p "$SESSIONS_DIR"

# Generate a unique session ID based on directory path
generate_session_id() {
    local work_dir="$1"
    local dir_hash=$(echo -n "$work_dir" | sha256sum | cut -c1-8)
    local timestamp=$(date +%s)
    echo "jmux-${dir_hash}-${timestamp}"
}

# Create session metadata file
create_session_metadata() {
    local session_id="$1"
    local work_dir="$2"
    local start_time="$3"
    local pid="$4"
    
    cat > "$SESSIONS_DIR/$session_id.meta" <<EOF
SESSION_ID=$session_id
WORK_DIR=$work_dir
START_TIME=$start_time
PID=$pid
CREATED=$(date -Iseconds)
EOF
}

# Load session metadata
load_session_metadata() {
    local session_id="$1"
    local meta_file="$SESSIONS_DIR/$session_id.meta"
    
    if [ -f "$meta_file" ]; then
        . "$meta_file"
        return 0
    else
        return 1
    fi
}

# List all active jmux sessions
list_sessions() {
    echo "Active jmux sessions:"
    echo "===================="
    
    local found_active=false
    
    # Get all tmux sessions that match jmux pattern
    local tmux_sessions=$(tmux list-sessions 2>/dev/null | grep "^jmux-" | cut -d: -f1 || true)
    
    if [ -z "$tmux_sessions" ]; then
        echo "No active jmux sessions found."
        return 0
    fi
    
    for session_id in $tmux_sessions; do
        if load_session_metadata "$session_id" 2>/dev/null; then
            local short_dir=$(basename "$WORK_DIR")
            local parent_dir=$(dirname "$WORK_DIR" | sed "s|$HOME|~|")
            if [ "$parent_dir" != "." ]; then
                short_dir="$parent_dir/$short_dir"
            fi
            
            # Check if session is actually running
            if tmux has-session -t "$session_id" 2>/dev/null; then
                echo "  $session_id"
                echo "    Directory: $short_dir"
                echo "    Full path: $WORK_DIR"
                echo "    Started: $CREATED"
                echo ""
                found_active=true
            else
                # Clean up stale metadata
                rm -f "$SESSIONS_DIR/$session_id.meta"
            fi
        else
            # Session exists in tmux but no metadata - could be legacy
            if tmux has-session -t "$session_id" 2>/dev/null; then
                echo "  $session_id (legacy session - no metadata)"
                echo ""
                found_active=true
            fi
        fi
    done
    
    if [ "$found_active" = false ]; then
        echo "No active jmux sessions found."
    fi
}

# Kill a specific session
kill_session() {
    local session_id="$1"
    
    if [ -z "$session_id" ]; then
        echo "Usage: kill_session <session_id>"
        echo "Use 'list_sessions' to see available sessions."
        return 1
    fi
    
    # Check if session exists
    if ! tmux has-session -t "$session_id" 2>/dev/null; then
        echo "Error: Session '$session_id' not found."
        return 1
    fi
    
    # Load metadata if available
    local work_dir="unknown"
    if load_session_metadata "$session_id" 2>/dev/null; then
        work_dir="$WORK_DIR"
    fi
    
    echo "Killing jmux session: $session_id"
    echo "Working directory: $work_dir"
    
    # Kill the tmux session
    tmux kill-session -t "$session_id" 2>/dev/null || true
    
    # Clean up metadata
    rm -f "$SESSIONS_DIR/$session_id.meta"
    
    # Clean up any associated temporary files
    rm -f "/tmp/jmux_wrapper_*$session_id*" 2>/dev/null || true
    rm -f "/tmp/jmux_cache_script_*$session_id*" 2>/dev/null || true
    
    echo "Session killed successfully."
}

# Kill all jmux sessions
kill_all_sessions() {
    echo "Killing all jmux sessions..."
    
    local tmux_sessions=$(tmux list-sessions 2>/dev/null | grep "^jmux-" | cut -d: -f1 || true)
    
    if [ -z "$tmux_sessions" ]; then
        echo "No active jmux sessions found."
        return 0
    fi
    
    local killed_count=0
    for session_id in $tmux_sessions; do
        if tmux has-session -t "$session_id" 2>/dev/null; then
            tmux kill-session -t "$session_id" 2>/dev/null || true
            rm -f "$SESSIONS_DIR/$session_id.meta"
            killed_count=$((killed_count + 1))
        fi
    done
    
    
    # Clean up temporary files
    rm -f /tmp/jmux_wrapper_* /tmp/jmux_cache_script_* 2>/dev/null || true
    pkill -f "jmux_files_cache" 2>/dev/null || true
    
    echo "Killed $killed_count jmux session(s)."
}

# Attach to a specific session
attach_session() {
    local session_id="$1"
    
    if [ -z "$session_id" ]; then
        echo "Usage: attach_session <session_id>"
        echo "Use 'list_sessions' to see available sessions."
        return 1
    fi
    
    # Check if session exists
    if ! tmux has-session -t "$session_id" 2>/dev/null; then
        echo "Error: Session '$session_id' not found."
        return 1
    fi
    
    # Load metadata if available
    if load_session_metadata "$session_id" 2>/dev/null; then
        echo "Attaching to jmux session: $session_id"
        echo "Working directory: $WORK_DIR"
    else
        echo "Attaching to jmux session: $session_id (legacy session)"
    fi
    
    # Attach to the session
    tmux attach-session -t "$session_id"
}

# Find existing session for a directory
find_session_for_directory() {
    local target_dir="$1"
    
    # Get all jmux sessions
    local tmux_sessions=$(tmux list-sessions 2>/dev/null | grep "^jmux-" | cut -d: -f1 || true)
    
    for session_id in $tmux_sessions; do
        if load_session_metadata "$session_id" 2>/dev/null; then
            if [ "$WORK_DIR" = "$target_dir" ] && tmux has-session -t "$session_id" 2>/dev/null; then
                echo "$session_id"
                return 0
            fi
        fi
    done
    
    return 1
}

# Clean up stale metadata files
cleanup_stale_metadata() {
    if ls "$SESSIONS_DIR"/*.meta >/dev/null 2>&1; then
        for meta_file in "$SESSIONS_DIR"/*.meta; do
            [ -f "$meta_file" ] || continue
            
            local session_id=$(basename "$meta_file" .meta)
            if ! tmux has-session -t "$session_id" 2>/dev/null; then
                rm -f "$meta_file"
            fi
        done
    fi
}

# Main command dispatch
case "${1:-list}" in
    "generate-id")
        generate_session_id "$2"
        ;;
    "create-meta")
        create_session_metadata "$2" "$3" "$4" "$5"
        ;;
    "list")
        cleanup_stale_metadata
        list_sessions
        ;;
    "kill")
        kill_session "$2"
        ;;
    "kill-all")
        kill_all_sessions
        ;;
    "attach")
        attach_session "$2"
        ;;
    "find-for-dir")
        find_session_for_directory "$2"
        ;;
    "cleanup-stale")
        cleanup_stale_metadata
        ;;
    *)
        echo "Usage: $0 {list|kill <session_id>|kill-all|attach <session_id>|find-for-dir <dir>}"
        echo ""
        echo "Commands:"
        echo "  list              - List all active jmux sessions"
        echo "  kill <session_id> - Kill a specific session"
        echo "  kill-all          - Kill all jmux sessions"
        echo "  attach <session_id> - Attach to a specific session"
        echo "  find-for-dir <dir> - Find existing session for directory"
        echo "  cleanup-stale     - Remove stale metadata files"
        exit 1
        ;;
esac