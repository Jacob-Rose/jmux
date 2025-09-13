#!/bin/bash

# Test script to simulate ranger Enter key press
cd /home/jakee/jmux

# Set up environment like jmux would
export RANGER_FOCUSED_RATIO=40
export NVIM_FOCUSED_RATIO=30

# Test the enter helper directly
echo "Testing enter helper with test file..."
./scripts/enter_helper.sh ./test_file.txt $(pwd)

echo "Checking logs..."
./scripts/view_logs.sh enter_helper