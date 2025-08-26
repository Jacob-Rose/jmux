#!/bin/bash

# Terminal command menu for jmux tabbed terminal
# Provides :1, :2, :3, :q commands similar to ranger interface

SESSION_NAME="jmux-persist-terminal"

show_command_menu() {
    clear
    cat << 'MENU_EOF'
┌─────────────────────────────────────────────────────────────┐
│                    📟 TERMINAL COMMANDS 📟                  │
├─────────────────────────────────────────────────────────────┤
│  :1  - Switch to Terminal 1                                │
│  :2  - Switch to Terminal 2                                │
│  :3  - Switch to Terminal 3                                │
│  :n  - Next terminal                                       │
│  :p  - Previous terminal                                   │
│  :q  - Return to jmux                                      │
│                                                             │
│  Enter command or press Escape to cancel                   │
└─────────────────────────────────────────────────────────────┘
MENU_EOF
    echo -n "Command: :"
}

read_command() {
    local cmd=""
    while IFS= read -r -n1 char; do
        case "$char" in
            $'\n'|$'\r')
                echo ""
                break
                ;;
            $'\x1b'|$'\x03')  # Escape or Ctrl+C
                echo ""
                echo "Cancelled"
                return 1
                ;;
            $'\x7f'|$'\x08')  # Backspace
                if [ ${#cmd} -gt 0 ]; then
                    cmd="${cmd%?}"
                    printf "\b \b"
                fi
                ;;
            *)
                cmd="$cmd$char"
                printf "%s" "$char"
                ;;
        esac
    done
    
    echo "$cmd"
    return 0
}

execute_command() {
    local cmd="$1"
    
    case "$cmd" in
        "1")
            tmux select-window -t "$SESSION_NAME:0"
            echo "→ Switched to Terminal 1"
            ;;
        "2") 
            tmux select-window -t "$SESSION_NAME:1"
            echo "→ Switched to Terminal 2"
            ;;
        "3")
            tmux select-window -t "$SESSION_NAME:2"
            echo "→ Switched to Terminal 3"
            ;;
        "n"|"next")
            tmux next-window -t "$SESSION_NAME"
            echo "→ Next terminal"
            ;;
        "p"|"prev"|"previous")
            tmux previous-window -t "$SESSION_NAME"
            echo "→ Previous terminal"
            ;;
        "q"|"quit"|"exit")
            echo "→ Returning to jmux..."
            tmux detach-client
            ;;
        "help"|"h"|"?")
            show_command_menu
            return 2  # Show menu again
            ;;
        "")
            echo "No command entered"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Use :help or :? for available commands"
            ;;
    esac
    
    return 0
}

# Main command interface
main() {
    show_command_menu
    
    while true; do
        if command=$(read_command); then
            result=$(execute_command "$command")
            exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                echo "$result"
                sleep 0.5
                break
            elif [ $exit_code -eq 2 ]; then
                # Show menu again
                continue
            else
                break
            fi
        else
            # User cancelled
            break
        fi
    done
}

main "$@"