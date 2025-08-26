#!/bin/bash

# Configuration utility functions - testable without tmux dependencies

# Load configuration from key=value file
# Usage: load_config "/path/to/config"
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    # Source the config file in a safe way
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        case "$key" in
            '#'*|'') continue ;;
        esac
        
        # Remove quotes from value
        value="${value%\"}"
        value="${value#\"}"
        
        # Export the variable
        export "$key=$value"
    done < "$config_file"
}

# Save a configuration setting
# Usage: save_config_setting "/path/to/config" "KEY" "value"
save_config_setting() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    local temp_file="${config_file}.tmp"
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Create new config file without the old key
    if [ -f "$config_file" ]; then
        grep -v "^$key=" "$config_file" > "$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi
    
    # Add the new setting
    echo "$key=\"$value\"" >> "$temp_file"
    mv "$temp_file" "$config_file"
}

# Get configuration value
# Usage: get_config_value "/path/to/config" "KEY" "default_value"
get_config_value() {
    local config_file="$1"
    local key="$2"
    local default_value="$3"
    
    if [ -f "$config_file" ]; then
        local value="$(grep "^$key=" "$config_file" | cut -d'=' -f2- | tr -d '"')"
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    
    echo "$default_value"
}

# Validate configuration file format
# Usage: validate_config_format "/path/to/config"
validate_config_format() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        case "$line" in
            '#'*|'') continue ;;
        esac
        
        # Check for valid key=value format
        if ! echo "$line" | grep -q '^[A-Z_][A-Z0-9_]*='; then
            return 1
        fi
    done < "$config_file"
    
    return 0
}

# Merge two configuration files (second overrides first)
# Usage: merge_configs "/path/to/base.conf" "/path/to/override.conf" "/path/to/output.conf"
merge_configs() {
    local base_config="$1"
    local override_config="$2"
    local output_config="$3"
    local temp_file="${output_config}.tmp"
    
    # Start with base config
    if [ -f "$base_config" ]; then
        cp "$base_config" "$temp_file"
    else
        touch "$temp_file"
    fi
    
    # Apply overrides
    if [ -f "$override_config" ]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            case "$key" in
                '#'*|'') continue ;;
            esac
            
            # Remove existing key and add new value
            grep -v "^$key=" "$temp_file" > "${temp_file}.2" || touch "${temp_file}.2"
            echo "$key=$value" >> "${temp_file}.2"
            mv "${temp_file}.2" "$temp_file"
        done < "$override_config"
    fi
    
    mv "$temp_file" "$output_config"
}