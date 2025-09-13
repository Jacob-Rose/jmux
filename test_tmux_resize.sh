#!/bin/bash

# Test script to reproduce the tmux resize issue
# This simulates what happens when a file is opened

echo "Testing tmux resize commands that might cause 'size missing' error..."

# Test various resize percentages to see which ones fail
for pct in 10 15 20 25 30 35 40; do
    echo "Testing resize to ${pct}%..."
    
    # Create a test tmux session
    SESSION_NAME="jmux-test-$$"
    tmux new-session -d -s "$SESSION_NAME" -x 80 -y 24 "sleep 60" 2>/dev/null || continue
    
    # Split into two panes
    tmux split-window -t "$SESSION_NAME" -h "sleep 60" 2>/dev/null || {
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null
        continue
    }
    
    # Try to resize pane 0 to the test percentage
    echo -n "  Resize to ${pct}%: "
    if tmux resize-pane -t "$SESSION_NAME:0.0" -x "${pct}%" 2>/dev/null; then
        echo "SUCCESS"
    else
        echo "FAILED (possible size missing error)"
    fi
    
    # Clean up
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
done

echo "Done testing resize percentages."