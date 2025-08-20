#!/bin/bash

# Settings Menu for jmux
# Provides theme selection and other configuration options

# Ensure we're in a proper terminal environment
export TERM=${TERM:-xterm-256color}

# Available nvim themes
themes=(
    "default"
    "desert"
    "evening"
    "industry"
    "koehler"
    "morning"
    "murphy"
    "pablo"
    "peachpuff"
    "ron"
    "shine"
    "slate"
    "torte"
    "zellner"
    "blue"
    "darkblue"
    "delek"
    "elflord"
    "habamax"
    "lunaperche"
    "quiet"
    "retrobox"
    "sorbet"
    "wildcharm"
)

# Settings file location
SETTINGS_FILE="$HOME/.config/jmux/settings"

# Load current settings
if [ -f "$SETTINGS_FILE" ]; then
    source "$SETTINGS_FILE"
fi

# Default theme if not set
CURRENT_THEME="${JMUX_THEME:-default}"

# Main settings menu function
show_main_menu() {
    clear
    echo "=== jmux Settings ==="
    echo ""
    echo "1) Neovim Settings"
    echo "2) Ranger Settings" 
    echo "3) Tmux Settings"
    echo ""
    echo "Enter option number (1-3) or 'q' to quit:"
}

# Nvim settings submenu function
show_nvim_menu() {
    clear
    echo "=== Neovim Settings ==="
    echo "Current theme: $CURRENT_THEME"
    echo ""
    echo "1) Change colorscheme"
    echo "2) Back to main menu"
    echo ""
    echo "Enter option number (1-2) or 'q' to quit:"
}

# Theme selection menu function
show_theme_menu() {
    clear
    echo "=== Select Neovim Theme ==="
    echo "Current theme: $CURRENT_THEME"
    echo ""
    echo "Available themes:"

    # Display themes with numbers
    for i in "${!themes[@]}"; do
        num=$((i+1))
        if [ "${themes[$i]}" = "$CURRENT_THEME" ]; then
            echo "● $num) ${themes[$i]} (current)"
        else
            echo "  $num) ${themes[$i]}"
        fi
    done

    echo ""
    echo "Enter theme number (1-${#themes[@]}) or 'q' to quit:"
}

# Menu navigation function
read_menu_input() {
    local max_options=$1
    stty raw -echo
    choice=""
    while true; do
        char=$(dd bs=1 count=1 2>/dev/null)
        case "$char" in
            $'\n'|$'\r')
                break
                ;;
            $'\x7f'|$'\x08')  # Backspace
                if [ ${#choice} -gt 0 ]; then
                    choice="${choice%?}"
                    printf "\b \b"
                fi
                ;;
            $'\x03'|q)  # Ctrl+C or 'q'
                stty sane
                echo ""
                echo "Cancelled"
                exit 0
                ;;
            $'\x1b')  # ESC - check for arrow keys
                read -t 0.1 -n1 next_char 2>/dev/null
                if [ "$next_char" = "[" ]; then
                    read -t 0.1 -n1 arrow_char 2>/dev/null
                    # Ignore arrow keys
                else
                    stty sane
                    echo ""
                    echo "Cancelled"
                    exit 0
                fi
                ;;
            [0-9])
                if [ ${#choice} -lt 2 ]; then
                    choice="$choice$char"
                    printf "%s" "$char"
                fi
                ;;
        esac
    done
    stty sane
    echo ""
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_options" ]; then
        return $choice
    else
        return 0
    fi
}


# Start the main menu
show_main_menu

# Main menu navigation
read_menu_input 3
main_choice=$?

case $main_choice in
    1)  # Neovim Settings
        show_nvim_menu
        read_menu_input 2
        nvim_choice=$?
        
        case $nvim_choice in
            1)  # Change colorscheme
                show_theme_menu
                read_menu_input ${#themes[@]}
                theme_choice=$?
                
                if [ $theme_choice -gt 0 ]; then
                    SELECTED="${themes[$((theme_choice-1))]}"
                    
                    # Apply the theme
                    THEME="$SELECTED"
                    mkdir -p "$(dirname "$SETTINGS_FILE")"
                    echo "JMUX_THEME=\"$THEME\"" > "$SETTINGS_FILE"
                    tmux send-keys -t ide:dev.1 Escape ":colorscheme $THEME" Enter
                    echo "Theme changed to: $THEME"
                    sleep 1
                else
                    exit 0
                fi
                ;;
            2)  # Back to main menu (restart)
                exec "$0"
                ;;
            0)  # Invalid/cancelled
                exit 0
                ;;
        esac
        ;;
    2)  # Ranger Settings
        echo "Ranger settings - Coming soon!"
        sleep 1
        exit 0
        ;;
    3)  # Tmux Settings  
        echo "Tmux settings - Coming soon!"
        sleep 1
        exit 0
        ;;
    0)  # Invalid/cancelled
        exit 0
        ;;
esac