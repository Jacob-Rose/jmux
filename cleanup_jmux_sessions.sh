#!/bin/bash

# System-wide cleanup script for orphaned jmux sessions
# Can be run manually or via cron to clean up leaked sessions

echo "Cleaning up orphaned jmux sessions..."

# Kill orphaned tmux sessions
orphaned_sessions=$(tmux list-sessions 2>/dev/null | grep -E "^(ide|jmux-persist-terminal):" || true)
if [ -n "$orphaned_sessions" ]; then
    echo "Found orphaned jmux sessions:"
    echo "$orphaned_sessions"
    tmux kill-session -t ide 2>/dev/null || true
    tmux kill-session -t jmux-persist-terminal 2>/dev/null || true
fi

# Clean up orphaned processes
orphaned_cache_procs=$(pgrep -f "jmux_files_cache" 2>/dev/null || true)
if [ -n "$orphaned_cache_procs" ]; then
    echo "Killing orphaned cache processes: $orphaned_cache_procs"
    echo "$orphaned_cache_procs" | xargs kill 2>/dev/null || true
    sleep 1
    echo "$orphaned_cache_procs" | xargs kill -9 2>/dev/null || true
fi

# Clean up old files
echo "Cleaning up temporary files..."
rm -f /tmp/jmux_files_cache 2>/dev/null || true
rm -f /tmp/jmux_cache_pid 2>/dev/null || true
rm -f /tmp/jmux_main_pid 2>/dev/null || true
rm -f /tmp/jmux_cleanup_* 2>/dev/null || true
rm -f /tmp/jmux_cache_script_*.sh 2>/dev/null || true

# Clean up PID files older than 1 hour
find /tmp -name "jmux_session_*.pid" -mmin +60 -delete 2>/dev/null || true

echo "Cleanup completed."

# Show remaining tmux sessions for verification
remaining_sessions=$(tmux list-sessions 2>/dev/null | grep -E "(ide|jmux)" || true)
if [ -n "$remaining_sessions" ]; then
    echo "Warning: Some sessions still exist:"
    echo "$remaining_sessions"
else
    echo "No jmux sessions remaining."
fi