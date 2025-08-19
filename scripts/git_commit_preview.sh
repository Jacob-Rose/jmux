#!/bin/bash
# Show commit message for git log viewer
hash=$(echo "$1" | sed -n 's/.*\([a-f0-9]\{7,\}\).*/\1/p' | head -1)
if [ -n "$hash" ]; then
    git log -1 --pretty=format:"%B" --color=always "$hash"
fi