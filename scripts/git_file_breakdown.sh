#!/bin/bash
# Show file breakdown for commit
hash=$(echo "$1" | sed -n 's/.*\([a-f0-9]\{7,\}\).*/\1/p' | head -1)
if [ -n "$hash" ]; then
    if command -v delta >/dev/null 2>&1; then
    git show --color=always --stat --patch "$hash" | delta | less -R
  else
    git show --color=always --stat --patch "$hash" | less -R
  fi
fi