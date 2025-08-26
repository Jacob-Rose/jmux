#!/bin/bash

# Input utility functions - testable without tmux dependencies

# Validate numeric input within range
# Usage: validate_numeric_input "5" 1 10
validate_numeric_input() {
    local input="$1"
    local min="$2"
    local max="$3"
    
    # Check if input is numeric
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Check range
    if [ "$input" -lt "$min" ] || [ "$input" -gt "$max" ]; then
        return 1
    fi
    
    return 0
}

# Parse user choice from menu input
# Usage: parse_menu_choice "3" 5  # choice 3 out of 5 options
parse_menu_choice() {
    local choice="$1"
    local max_options="$2"
    
    # Validate input
    if validate_numeric_input "$choice" 1 "$max_options"; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Check if input is quit command
# Usage: is_quit_command "q"
is_quit_command() {
    local input="$1"
    
    case "$input" in
        q|Q|quit|QUIT|exit|EXIT) return 0 ;;
        *) return 1 ;;
    esac
}

# Sanitize user input (remove dangerous characters)
# Usage: sanitize_input "user input with; dangerous stuff"
sanitize_input() {
    local input="$1"
    
    # Remove dangerous shell characters
    echo "$input" | tr -d ';|&`$(){}[]<>*?'
}

# Validate boolean input
# Usage: validate_boolean "true"
validate_boolean() {
    local input="$1"
    
    case "$input" in
        true|false|TRUE|FALSE|yes|no|YES|NO|y|n|Y|N|1|0) return 0 ;;
        *) return 1 ;;
    esac
}

# Normalize boolean input to true/false
# Usage: normalize_boolean "yes"
normalize_boolean() {
    local input="$1"
    
    case "$input" in
        true|TRUE|yes|YES|y|Y|1) echo "true" ;;
        false|FALSE|no|NO|n|N|0) echo "false" ;;
        *) return 1 ;;
    esac
}

# Parse key-value pair from input
# Usage: parse_key_value "KEY=value"
parse_key_value() {
    local input="$1"
    
    if echo "$input" | grep -q '='; then
        local key="$(echo "$input" | cut -d'=' -f1)"
        local value="$(echo "$input" | cut -d'=' -f2-)"
        echo "$key|$value"
        return 0
    else
        return 1
    fi
}