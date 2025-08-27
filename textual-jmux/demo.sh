#!/bin/bash
# Quick demo script to test the textual jmux application

echo "🎉 Starting Textual jmux Demo"
echo "============================="
echo
echo "Instructions:"
echo "1. Use arrow keys to navigate the file tree"
echo "2. Double-click any file to open it in nvim"
echo "3. Press 'q' to quit"
echo
echo "Files to try double-clicking:"
echo "- test_files/sample.txt"
echo "- test_files/demo.py" 
echo "- README.md"
echo
echo "Starting application..."
sleep 2

cd "$(dirname "$0")"
python3 main.py