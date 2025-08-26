#!/bin/bash

# Theme utility functions - testable without tmux dependencies

# Get available nvim themes
# Usage: get_nvim_themes
get_nvim_themes() {
    echo "default
desert
evening
industry
koehler
morning
murphy
pablo
peachpuff
ron
shine
slate
torte
zellner
blue
darkblue
delek
elflord
habamax
lunaperche
quiet
retrobox
sorbet
wildcharm"
}

# Get available ranger themes  
# Usage: get_ranger_themes
get_ranger_themes() {
    echo "default
jungle
snow
solarized"
}

# Validate theme name for nvim
# Usage: is_valid_nvim_theme "theme_name"
is_valid_nvim_theme() {
    local theme="$1"
    local valid_themes="$(get_nvim_themes)"
    
    echo "$valid_themes" | grep -q "^$theme$"
}

# Validate theme name for ranger
# Usage: is_valid_ranger_theme "theme_name"
is_valid_ranger_theme() {
    local theme="$1"
    local valid_themes="$(get_ranger_themes)"
    
    echo "$valid_themes" | grep -q "^$theme$"
}

# Get theme by index (1-based)
# Usage: get_nvim_theme_by_index 5
get_nvim_theme_by_index() {
    local index="$1"
    
    if [ -z "$index" ] || [ "$index" -lt 1 ]; then
        return 1
    fi
    
    get_nvim_themes | sed -n "${index}p"
}

# Get ranger theme by index (1-based)
# Usage: get_ranger_theme_by_index 2
get_ranger_theme_by_index() {
    local index="$1"
    
    if [ -z "$index" ] || [ "$index" -lt 1 ]; then
        return 1
    fi
    
    get_ranger_themes | sed -n "${index}p"
}

# Get theme index by name (1-based)
# Usage: get_nvim_theme_index "slate"
get_nvim_theme_index() {
    local theme="$1"
    local themes="$(get_nvim_themes)"
    local index=1
    
    while IFS= read -r line; do
        if [ "$line" = "$theme" ]; then
            echo "$index"
            return 0
        fi
        index=$((index + 1))
    done <<< "$themes"
    
    return 1
}

# Count available themes
# Usage: count_nvim_themes
count_nvim_themes() {
    get_nvim_themes | wc -l
}

# Usage: count_ranger_themes  
count_ranger_themes() {
    get_ranger_themes | wc -l
}