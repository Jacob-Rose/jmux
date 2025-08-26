#!/bin/bash

# Path utility functions - testable without tmux dependencies

# Get absolute path from relative path
# Usage: get_absolute_path "path/to/directory"
get_absolute_path() {
    local path="$1"
    if [ -z "$path" ]; then
        echo "$(pwd)"
        return 0
    fi
    
    if [ -d "$path" ]; then
        (cd "$path" && pwd)
    elif [ -f "$path" ]; then
        local dir="$(dirname "$path")"
        local file="$(basename "$path")"
        echo "$(cd "$dir" && pwd)/$file"
    else
        # Path doesn't exist, try to resolve anyway
        case "$path" in
            /*) echo "$path" ;;  # Already absolute
            *) echo "$(pwd)/$path" ;;  # Make relative path absolute
        esac
    fi
}

# Check if path is within git repository
# Usage: is_git_repo "path/to/directory"
is_git_repo() {
    local path="${1:-$(pwd)}"
    local abs_path="$(get_absolute_path "$path")"
    
    # Change to directory and check for git
    (cd "$abs_path" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1)
}

# Get git repository root
# Usage: get_git_root "path/to/directory"
get_git_root() {
    local path="${1:-$(pwd)}"
    local abs_path="$(get_absolute_path "$path")"
    
    if is_git_repo "$abs_path"; then
        (cd "$abs_path" && git rev-parse --show-toplevel)
    else
        return 1
    fi
}

# Validate file extension
# Usage: has_extension "file.txt" "txt"
has_extension() {
    local file="$1"
    local expected_ext="$2"
    
    case "$file" in
        *."$expected_ext") return 0 ;;
        *) return 1 ;;
    esac
}

# Get file extension
# Usage: get_extension "file.txt"
get_extension() {
    local file="$1"
    echo "${file##*.}"
}

# Check if path is safe (no dangerous characters)
# Usage: is_safe_path "/path/to/file"
is_safe_path() {
    local path="$1"
    
    # Reject paths with dangerous patterns
    case "$path" in
        */../*|*/./*|*/.*) return 1 ;;
        *\;*|*\&*|*\|*|*\`*|*\$*) return 1 ;;
        *) return 0 ;;
    esac
}