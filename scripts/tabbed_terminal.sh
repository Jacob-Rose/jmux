#!/bin/bash

# Tabbed terminal popup for jmux
# Opens a popup with 3 terminal tabs in tmux session

WORK_DIR="${1:-$(pwd)}"

# Resolve to absolute path
WORK_DIR="$(cd "$WORK_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Directory '$1' does not exist"
    exit 1
}

# Use a persistent session name that's isolated from main IDE
SESSION_NAME="jmux-persist-terminal"

# Function to cleanup only temp files (NOT the session)
cleanup_temp_files() {
    rm -f "/tmp/jmux_init_$$.sh" 2>/dev/null || true
}

# Only trap for temp file cleanup - do NOT kill the session
trap cleanup_temp_files EXIT

# Ensure we're in the right directory
cd "$WORK_DIR" || exit 1

# Check if tmux is available
if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is not installed"
    exit 1
fi

# Check if terminal session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Reconnecting to existing terminal session..."
    # Session exists, just attach to it (remove all traps first)
    trap - EXIT INT TERM HUP QUIT
    tmux attach-session -t "$SESSION_NAME"
    # When detached, just clean temp files and exit
    cleanup_temp_files
    exit 0
fi

echo "Creating new terminal session..."

# Create new tmux session with first terminal, isolated from main IDE session
tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR"

# Configure session to be persistent and isolated
tmux set-option -t "$SESSION_NAME" destroy-unattached off  # Keep session alive when no clients
tmux set-option -t "$SESSION_NAME" detach-on-destroy off   # Don't exit tmux when this session ends
tmux set-option -t "$SESSION_NAME" exit-empty off          # Don't exit when no windows

# Rename first window and add more windows (using default 0-based indexing)
tmux rename-window -t "$SESSION_NAME:0" "Terminal-1"
tmux new-window -t "$SESSION_NAME" -c "$WORK_DIR" -n "Terminal-2"
tmux new-window -t "$SESSION_NAME" -c "$WORK_DIR" -n "Terminal-3"

# Configure status bar for better tab visibility
tmux set-option -t "$SESSION_NAME" status on
tmux set-option -t "$SESSION_NAME" status-position bottom
tmux set-option -t "$SESSION_NAME" status-style "bg=colour236,fg=colour255"
tmux set-option -t "$SESSION_NAME" window-status-style "bg=colour236,fg=colour244"
tmux set-option -t "$SESSION_NAME" window-status-current-style "bg=colour31,fg=colour255,bold"
tmux set-option -t "$SESSION_NAME" status-left "#[fg=colour255,bg=colour31,bold] JMUX TERMINAL #[default] "
tmux set-option -t "$SESSION_NAME" status-left-length 20
tmux set-option -t "$SESSION_NAME" status-right "#[fg=colour244] [Ctrl+B + 1/2/3/q] [Mouse: click tabs] #[default]"
tmux set-option -t "$SESSION_NAME" status-right-length 50

# Enable mouse support for this session
tmux set-option -t "$SESSION_NAME" mouse on

# Restore simple tmux key bindings that work
tmux set-option -t "$SESSION_NAME" prefix C-b

# Simple key bindings for terminal switching  
tmux bind-key -t "$SESSION_NAME" -T prefix 1 select-window -t "$SESSION_NAME:0"
tmux bind-key -t "$SESSION_NAME" -T prefix 2 select-window -t "$SESSION_NAME:1" 
tmux bind-key -t "$SESSION_NAME" -T prefix 3 select-window -t "$SESSION_NAME:2"
tmux bind-key -t "$SESSION_NAME" -T prefix q detach-client

# Create a hidden welcome script to avoid code spam
WELCOME_SCRIPT="/tmp/jmux_init_$$.sh"
cat > "$WELCOME_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
clear
cat << 'WELCOME_EOF'
═══════════════════════════════════════════════════════════════════════════════
                          📟 JMUX PERSISTENT TERMINAL 📟
═══════════════════════════════════════════════════════════════════════════════
  Current directory: __WORK_DIR__
  Available tabs: 3 persistent terminals
  
  This session persists when you exit - use :t in jmux to return anytime

  🔹 Navigation:
     Ctrl+B then 1/2/3  - Switch terminals      Ctrl+B then q - Return to jmux
     Ctrl+B then n/p    - Next/Previous         Mouse click - Click on tabs
═══════════════════════════════════════════════════════════════════════════════
WELCOME_EOF
SCRIPT_EOF

# Replace placeholders with actual values
sed -i "s|__WORK_DIR__|$WORK_DIR|g" "$WELCOME_SCRIPT"
chmod +x "$WELCOME_SCRIPT"

# Execute welcome script and start bash normally
tmux send-keys -t "$SESSION_NAME:0" "bash $WELCOME_SCRIPT && bash" Enter

# Simple setup for other terminals  
tmux send-keys -t "$SESSION_NAME:1" "clear && echo '📟 Terminal Tab 2 - $WORK_DIR' && echo 'Navigation: Ctrl+B + 1/2/3/q'" Enter
tmux send-keys -t "$SESSION_NAME:2" "clear && echo '📟 Terminal Tab 3 - $WORK_DIR' && echo 'Navigation: Ctrl+B + 1/2/3/q'" Enter

# Start on the first terminal (window 0)
tmux select-window -t "$SESSION_NAME:0"

# Check if this is a new session or reconnecting to existing
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Session exists, attach to it
    tmux attach-session -t "$SESSION_NAME"
else
    echo "Error: Failed to create terminal session"
    exit 1
fi

# When we get here, user has detached (Ctrl+B q) - don't cleanup, leave session running  
# Remove cleanup trap since we want the session to persist
trap - EXIT INT TERM HUP QUIT

# Clean up temp files only
cleanup_temp_files

# Verify session is still running
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "✓ Terminal session remains active (use :t to reconnect)"
else
    echo "⚠ Terminal session was lost"
fi

exit 0