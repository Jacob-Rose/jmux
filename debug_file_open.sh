#!/bin/bash

# Debug script to test file opening with full environment
cd /home/jakee/jmux

echo "=== Debugging File Open Issue ==="

# Find the latest portable config
LATEST_CONFIG=$(find /tmp -name "jmux_portable_*" -type d 2>/dev/null | sort | tail -1)
echo "Latest portable config: $LATEST_CONFIG"

if [ -n "$LATEST_CONFIG" ]; then
    echo "Contents of portable config:"
    ls -la "$LATEST_CONFIG"
    echo ""
    
    # Test the enter helper from the portable config
    ENTER_HELPER="$LATEST_CONFIG/enter_helper.sh"
    if [ -f "$ENTER_HELPER" ]; then
        echo "Testing enter helper from portable config..."
        echo "Command: $ENTER_HELPER ./test_file.txt $(pwd)"
        
        # Set up environment like jmux would
        export RANGER_FOCUSED_RATIO=40
        export NVIM_FOCUSED_RATIO=30
        
        # Run the enter helper and capture all output
        echo "=== Enter Helper Output ==="
        "$ENTER_HELPER" ./test_file.txt $(pwd) 2>&1
        echo "=== End Enter Helper Output ==="
        
        # Check if any logs were created
        echo ""
        echo "=== Checking for logs ==="
        ./scripts/view_logs.sh list
        
        echo ""
        echo "=== Enter Helper Log Content ==="
        ./scripts/view_logs.sh enter_helper 2>/dev/null || echo "No enter_helper log found"
        
    else
        echo "Enter helper not found in portable config"
    fi
else
    echo "No portable config found"
fi