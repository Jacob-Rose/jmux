#!/bin/bash

# Settings Menu for jmux
# Provides theme selection and other configuration options

# Load session utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/jmux_session_utils.sh"

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

# Apply saved ranger theme to current config if it exists
if [ -n "${JMUX_RANGER_THEME}" ]; then
    apply_ranger_theme "${JMUX_RANGER_THEME}"
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

# Ranger theme selection menu function
show_ranger_theme_menu() {
    clear
    echo "=== Select Ranger Theme ==="
    echo "Current theme: ${JMUX_RANGER_THEME:-default}"
    echo ""
    echo "Available themes:"
    
    local ranger_themes=("default" "jungle" "snow" "solarized")
    
    # Display themes with numbers
    for i in "${!ranger_themes[@]}"; do
        num=$((i+1))
        if [ "${ranger_themes[$i]}" = "${JMUX_RANGER_THEME:-default}" ]; then
            echo "● $num) ${ranger_themes[$i]} (current)"
        else
            echo "  $num) ${ranger_themes[$i]}"
        fi
    done
    
    echo ""
    echo "Enter theme number (1-${#ranger_themes[@]}) or 'q' to quit:"
    
    # Store themes array for later use
    RANGER_THEMES=("${ranger_themes[@]}")
}

# Ranger settings submenu function
show_ranger_menu() {
    clear
    echo "=== Ranger Settings ==="
    echo "Current theme: ${JMUX_RANGER_THEME:-default}"
    echo "Current hidden files: ${JMUX_SHOW_HIDDEN:-false}"
    echo "Current preview: ${JMUX_SHOW_PREVIEW:-false}"
    echo "Current auto-switch to nvim: ${JMUX_AUTO_SWITCH:-true}"
    echo "Current directory restriction: ${JMUX_RESTRICT_NAVIGATION:-true}"
    echo ""
    echo "1) Change colorscheme"
    echo "2) Toggle hidden files visibility"
    echo "3) Toggle file preview"
    echo "4) Toggle auto-switch to nvim on file open"
    echo "5) Toggle directory restriction"
    echo "6) Back to main menu"
    echo ""
    echo "Enter option number (1-6) or 'q' to quit:"
}

# Tmux settings submenu function
show_tmux_menu() {
    clear
    echo "=== Tmux Settings ==="
    echo "Current pane split: ${JMUX_PANE_SPLIT:-40:60}"
    echo "Current status bar: ${JMUX_STATUS_BAR:-on}"
    echo ""
    echo "1) Change pane split ratio"
    echo "2) Toggle status bar"
    echo "3) Back to main menu"
    echo ""
    echo "Enter option number (1-3) or 'q' to quit:"
}

# Pane split selection menu
show_split_menu() {
    clear
    echo "=== Select Pane Split Ratio ==="
    echo "Current: ${JMUX_PANE_SPLIT:-40:60}"
    echo ""
    echo "1) 30:70 (narrow file manager)"
    echo "2) 40:60 (balanced - default)"
    echo "3) 50:50 (equal split)"
    echo "4) 60:40 (wide file manager)"
    echo "5) Back to tmux menu"
    echo ""
    echo "Enter option number (1-5) or 'q' to quit:"
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

# Helper function to save settings
save_setting() {
    local key="$1"
    local value="$2"
    local temp_file="${SETTINGS_FILE}.tmp"
    
    # Create settings directory if it doesn't exist
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    
    # Create new settings file without the old key
    if [ -f "$SETTINGS_FILE" ]; then
        grep -v "^$key=" "$SETTINGS_FILE" > "$temp_file" 2>/dev/null || true
    else
        touch "$temp_file"
    fi
    
    # Add the new setting
    echo "$key=\"$value\"" >> "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"
}

# Apply ranger settings
apply_ranger_settings() {
    local config_file="$HOME/.config/jmux/ranger_config/rc.conf"
    
    if [ -f "$config_file" ]; then
        # Update show_hidden setting
        if [ "${JMUX_SHOW_HIDDEN:-false}" = "true" ]; then
            sed -i 's/set show_hidden false/set show_hidden true/' "$config_file"
        else
            sed -i 's/set show_hidden true/set show_hidden false/' "$config_file"
        fi
        
        # Update preview settings
        if [ "${JMUX_SHOW_PREVIEW:-false}" = "true" ]; then
            sed -i 's/set preview_files false/set preview_files true/' "$config_file"
            sed -i 's/set preview_directories false/set preview_directories true/' "$config_file"
        else
            sed -i 's/set preview_files true/set preview_files false/' "$config_file"
            sed -i 's/set preview_directories true/set preview_directories false/' "$config_file"
        fi
        
        # Theme saved to config - restart jmux to apply changes
    fi
}

# Apply ranger theme
apply_ranger_theme() {
    local theme="$1"
    local config_file="$HOME/.config/jmux/ranger_config/rc.conf"
    
    if [ -f "$config_file" ]; then
        # Remove existing colorscheme line and add new one
        sed -i '/^set colorscheme /d' "$config_file"
        echo "set colorscheme $theme" >> "$config_file"
        
        # Theme saved to config - restart jmux to apply changes
    fi
}

# Apply tmux settings
apply_tmux_settings() {
    # Apply status bar setting
    if [ "${JMUX_STATUS_BAR:-on}" = "on" ]; then
        tmux set-option -t ide status on
    else
        tmux set-option -t ide status off
    fi
    
    # Apply pane split (requires restart for full effect)
    # Just show message for now - would need jmux restart for split change
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
                    # Apply theme to current nvim session
                    if is_jmux_session; then
                        send_to_nvim Escape ":colorscheme $THEME" Enter
                    fi
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
        show_ranger_menu
        read_menu_input 6
        ranger_choice=$?
        
        case $ranger_choice in
            1)  # Change colorscheme
                show_ranger_theme_menu
                read_menu_input ${#RANGER_THEMES[@]}
                theme_choice=$?
                
                if [ $theme_choice -gt 0 ]; then
                    SELECTED_RANGER_THEME="${RANGER_THEMES[$((theme_choice-1))]}"
                    save_setting "JMUX_RANGER_THEME" "$SELECTED_RANGER_THEME"
                    apply_ranger_theme "$SELECTED_RANGER_THEME"
                    echo "Ranger theme saved: $SELECTED_RANGER_THEME"
                    echo "Restart jmux to apply the new theme"
                    sleep 2
                    exec "$0"
                else
                    exit 0
                fi
                ;;
            2)  # Toggle hidden files
                if [ "${JMUX_SHOW_HIDDEN:-false}" = "true" ]; then
                    JMUX_SHOW_HIDDEN="false"
                else
                    JMUX_SHOW_HIDDEN="true"
                fi
                # Save setting
                save_setting "JMUX_SHOW_HIDDEN" "$JMUX_SHOW_HIDDEN"
                apply_ranger_settings
                echo "Hidden files visibility changed to: $JMUX_SHOW_HIDDEN"
                sleep 1
                exec "$0"
                ;;
            3)  # Toggle preview
                if [ "${JMUX_SHOW_PREVIEW:-false}" = "true" ]; then
                    JMUX_SHOW_PREVIEW="false"
                else
                    JMUX_SHOW_PREVIEW="true"
                fi
                # Save setting
                save_setting "JMUX_SHOW_PREVIEW" "$JMUX_SHOW_PREVIEW"
                apply_ranger_settings
                echo "File preview changed to: $JMUX_SHOW_PREVIEW"
                sleep 1
                exec "$0"
                ;;
            4)  # Toggle auto-switch to nvim
                if [ "${JMUX_AUTO_SWITCH:-true}" = "true" ]; then
                    JMUX_AUTO_SWITCH="false"
                else
                    JMUX_AUTO_SWITCH="true"
                fi
                # Save setting
                save_setting "JMUX_AUTO_SWITCH" "$JMUX_AUTO_SWITCH"
                
                # Apply immediately to current session by updating ranger config
                RANGER_CONFIG="$HOME/.config/jmux/ranger_config/rc.conf"
                if [ "$JMUX_AUTO_SWITCH" = "true" ]; then
                    # Remove existing Enter mapping and add auto-switch version
                    grep -v "^map <Enter>" "$RANGER_CONFIG" > "${RANGER_CONFIG}.tmp"
                    # Create a helper script for the Enter command
                    cat > "$HOME/.config/jmux/enter_helper.sh" << 'ENTER_EOF'
#!/bin/bash
# Try multiple locations for session utils
for UTILS_PATH in "/usr/local/bin/jmux-scripts/jmux_session_utils.sh" \
                  "$HOME/Documents/jmux/scripts/jmux_session_utils.sh" \
                  "$(dirname "$0")/jmux_session_utils.sh"; do
    if [ -f "$UTILS_PATH" ]; then
        source "$UTILS_PATH"
        break
    fi
done
if is_jmux_session && has_nvim_pane; then
    send_to_nvim Escape ":lua open_file_in_main_editor('$(readlink -f "$1")')" Enter
    select_nvim_pane
    tmux resize-pane -t 0 -x "$(get_nvim_ratio)%"
else
    TARGET=$(get_jmux_target)
    if [ -n "$TARGET" ]; then
        tmux split-window -t "$TARGET" -h -p 60 "cd '$2' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$1")'"
        select_nvim_pane
        tmux resize-pane -t 0 -x "$(get_nvim_ratio)%"
    fi
fi
ENTER_EOF
                    chmod +x "$HOME/.config/jmux/enter_helper.sh"
                    echo "map <Enter> shell \$HOME/.config/jmux/enter_helper.sh %p %d" >> "${RANGER_CONFIG}.tmp"
                else
                    # Remove existing Enter mapping and add no-switch version
                    grep -v "^map <Enter>" "$RANGER_CONFIG" > "${RANGER_CONFIG}.tmp"
                    # Create a helper script for the Enter command (no-switch version)
                    cat > "$HOME/.config/jmux/enter_helper_noswitch.sh" << 'ENTER_EOF'
#!/bin/bash
# Try multiple locations for session utils
for UTILS_PATH in "/usr/local/bin/jmux-scripts/jmux_session_utils.sh" \
                  "$HOME/Documents/jmux/scripts/jmux_session_utils.sh" \
                  "$(dirname "$0")/jmux_session_utils.sh"; do
    if [ -f "$UTILS_PATH" ]; then
        source "$UTILS_PATH"
        break
    fi
done
if is_jmux_session && has_nvim_pane; then
    send_to_nvim Escape ":lua open_file_in_main_editor('$(readlink -f "$1")')" Enter
    # Stay in ranger - don't switch panes
else
    TARGET=$(get_jmux_target)
    if [ -n "$TARGET" ]; then
        tmux split-window -t "$TARGET" -h -p 60 "cd '$2' && nvim -u '$HOME/.config/jmux/nvim_config/init.lua' '$(readlink -f "$1")'"
        select_ranger_pane
    fi
fi
ENTER_EOF
                    chmod +x "$HOME/.config/jmux/enter_helper_noswitch.sh"
                    echo "map <Enter> shell \$HOME/.config/jmux/enter_helper_noswitch.sh %p %d" >> "${RANGER_CONFIG}.tmp"
                fi
                mv "${RANGER_CONFIG}.tmp" "$RANGER_CONFIG"
                
                # Try to reload ranger config automatically
                if is_jmux_session; then
                    send_to_ranger C-r
                fi
                
                echo "Auto-switch to nvim changed to: $JMUX_AUTO_SWITCH"
                echo "Ranger config reloaded - setting is now active!"
                sleep 2
                exec "$0"
                ;;
            5)  # Toggle directory restriction
                if [ "${JMUX_RESTRICT_NAVIGATION:-true}" = "true" ]; then
                    JMUX_RESTRICT_NAVIGATION="false"
                else
                    JMUX_RESTRICT_NAVIGATION="true"
                fi
                # Save setting
                save_setting "JMUX_RESTRICT_NAVIGATION" "$JMUX_RESTRICT_NAVIGATION"
                
                echo "Directory restriction changed to: $JMUX_RESTRICT_NAVIGATION"
                echo "Restart jmux session to apply this change"
                sleep 2
                exec "$0"
                ;;
            6)  # Back to main menu
                exec "$0"
                ;;
            0)  # Invalid/cancelled
                exit 0
                ;;
        esac
        ;;
    3)  # Tmux Settings  
        show_tmux_menu
        read_menu_input 3
        tmux_choice=$?
        
        case $tmux_choice in
            1)  # Change pane split
                show_split_menu
                read_menu_input 5
                split_choice=$?
                
                case $split_choice in
                    1) JMUX_PANE_SPLIT="30:70" ;;
                    2) JMUX_PANE_SPLIT="40:60" ;;
                    3) JMUX_PANE_SPLIT="50:50" ;;
                    4) JMUX_PANE_SPLIT="60:40" ;;
                    5) exec "$0" ;;  # Back to tmux menu
                    0) exit 0 ;;     # Invalid/cancelled
                esac
                
                if [ -n "$JMUX_PANE_SPLIT" ]; then
                    save_setting "JMUX_PANE_SPLIT" "$JMUX_PANE_SPLIT"
                    apply_tmux_settings
                    echo "Pane split changed to: $JMUX_PANE_SPLIT"
                    sleep 1
                    exec "$0"
                fi
                ;;
            2)  # Toggle status bar
                if [ "${JMUX_STATUS_BAR:-on}" = "on" ]; then
                    JMUX_STATUS_BAR="off"
                else
                    JMUX_STATUS_BAR="on"
                fi
                save_setting "JMUX_STATUS_BAR" "$JMUX_STATUS_BAR"
                apply_tmux_settings
                echo "Status bar changed to: $JMUX_STATUS_BAR"
                sleep 1
                exec "$0"
                ;;
            3)  # Back to main menu
                exec "$0"
                ;;
            0)  # Invalid/cancelled
                exit 0
                ;;
        esac
        ;;
    0)  # Invalid/cancelled
        exit 0
        ;;
esac