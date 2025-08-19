#!/bin/bash
# Interactive git log viewer for jmux
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"

git log --graph --all --decorate --color=always \
    --pretty=format:"%C(yellow)%h%C(reset) - %C(cyan)%an%C(reset) %C(dim)%ar%C(reset)%C(auto)%d%C(reset) %s" | \
fzf --ansi \
    --preview="$CONFIG_BASE/git_commit_preview.sh {}" \
    --preview-window=down:50%:wrap \
    --bind="enter:execute($CONFIG_BASE/git_file_breakdown.sh {})" \
    --bind="double-click:ignore"