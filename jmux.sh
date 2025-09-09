#!/bin/bash

# jmux: A tmux-based IDE with ranger and nvim
# Usage: jmux [directory]

# Set terminal title for status bars
WORK_DIR_FOR_TITLE="${1:-$(pwd)}"
WORK_DIR_FOR_TITLE="$(cd "$WORK_DIR_FOR_TITLE" 2>/dev/null && pwd || echo "$WORK_DIR_FOR_TITLE")"
TERMINAL_TITLE="jmux - $(basename "$WORK_DIR_FOR_TITLE")"

# Set terminal title using ANSI escape codes
printf '\033]0;%s\007' "$TERMINAL_TITLE"
#
# Features:
#   - File manager (ranger) with nvim integration
#   - Git integration (:g for lazygit, :gl for git log)
#   - Fuzzy file finder (Ctrl+P)
#   - Settings menu (:s)  
#   - Tabbed terminal (:t)
#
# Cleanup: If sessions become orphaned, run:
#   ./cleanup_jmux_sessions.sh
#
# The script includes comprehensive cleanup on exit, but in extreme cases
# (system crashes, kill -9, etc.) manual cleanup may be needed.

# Handle command line arguments for session management
case "${1:-}" in
    "list")
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        if [ -f "$SCRIPT_DIR/scripts/session_manager.sh" ]; then
            "$SCRIPT_DIR/scripts/session_manager.sh" list
        else
            # Try installed location
            "/usr/local/bin/jmux-scripts/session_manager.sh" list 2>/dev/null || echo "Session manager not found."
        fi
        exit 0
        ;;
    "kill")
        if [ -z "$2" ]; then
            echo "Usage: jmux kill <session_id>"
            echo "Use 'jmux list' to see available sessions."
            exit 1
        fi
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        if [ -f "$SCRIPT_DIR/scripts/session_manager.sh" ]; then
            "$SCRIPT_DIR/scripts/session_manager.sh" kill "$2"
        else
            "/usr/local/bin/jmux-scripts/session_manager.sh" kill "$2" 2>/dev/null || echo "Session manager not found."
        fi
        exit 0
        ;;
    "kill-all")
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        if [ -f "$SCRIPT_DIR/scripts/session_manager.sh" ]; then
            "$SCRIPT_DIR/scripts/session_manager.sh" kill-all
        else
            "/usr/local/bin/jmux-scripts/session_manager.sh" kill-all 2>/dev/null || echo "Session manager not found."
        fi
        exit 0
        ;;
    "attach")
        if [ -z "$2" ]; then
            echo "Usage: jmux attach <session_id>"
            echo "Use 'jmux list' to see available sessions."
            exit 1
        fi
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        if [ -f "$SCRIPT_DIR/scripts/session_manager.sh" ]; then
            "$SCRIPT_DIR/scripts/session_manager.sh" attach "$2"
        else
            "/usr/local/bin/jmux-scripts/session_manager.sh" attach "$2" 2>/dev/null || echo "Session manager not found."
        fi
        exit 0
        ;;
esac

# Set working directory (use argument or current directory, skipping session management commands)
if [[ "$1" =~ ^(list|kill|kill-all|attach)$ ]]; then
    WORK_DIR="$(pwd)"
else
    WORK_DIR="${1:-$(pwd)}"
fi
WORK_DIR="$(cd "$WORK_DIR" && pwd)"  # Get absolute path

# Load session manager functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/scripts/session_manager.sh" ]; then
    SESSION_MANAGER="$SCRIPT_DIR/scripts/session_manager.sh"
elif [ -f "/usr/local/bin/jmux-scripts/session_manager.sh" ]; then
    SESSION_MANAGER="/usr/local/bin/jmux-scripts/session_manager.sh"
else
    echo "Error: Session manager not found."
    exit 1
fi

# Check if there's already a session for this directory
check_existing_session() {
    local existing_session="$($SESSION_MANAGER find-for-dir "$WORK_DIR" 2>/dev/null || true)"
    if [ -n "$existing_session" ]; then
        echo "Found existing jmux session for this directory: $existing_session"
        read -p "Attach to existing session? [Y/n]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "Creating new session..."
        else
            echo "Attaching to existing session: $existing_session"
            "$SESSION_MANAGER" attach "$existing_session"
            exit 0
        fi
    fi
}

# Only check for existing sessions in interactive mode
if [ -t 0 ]; then
    check_existing_session
fi

# Generate unique session ID and store session info
JMUX_SESSION_ID="$($SESSION_MANAGER generate-id "$WORK_DIR")"
JMUX_PID_FILE="/tmp/jmux_session_${JMUX_SESSION_ID##*-}.pid"
START_TIME=$(date +%s)

# Create session metadata
"$SESSION_MANAGER" create-meta "$JMUX_SESSION_ID" "$WORK_DIR" "$START_TIME" "$$"

# Comprehensive cleanup function 
cleanup() {
    local exit_code=${1:-0}
    local cleanup_reason="${2:-normal}"
    
    # Prevent multiple cleanup calls
    if [ -f "/tmp/jmux_cleanup_$$" ]; then
        return 0
    fi
    touch "/tmp/jmux_cleanup_$$"
    
    echo ""
    echo "Cleaning up jmux session (reason: $cleanup_reason)..."
    
    # Kill any background cache process by PID
    if [ -f "/tmp/jmux_cache_pid" ]; then
        local cache_pid="$(cat /tmp/jmux_cache_pid 2>/dev/null)"
        if [ -n "$cache_pid" ] && kill -0 "$cache_pid" 2>/dev/null; then
            kill "$cache_pid" 2>/dev/null || true
            # Wait a moment for graceful shutdown
            sleep 0.1
            kill -9 "$cache_pid" 2>/dev/null || true
        fi
        rm -f /tmp/jmux_cache_pid
    fi
    
    # Kill any remaining find processes for file caching (more specific pattern)
    pkill -f "jmux_files_cache" 2>/dev/null || true
    
    # Force kill any remaining tmux sessions that might be orphaned
    # First try graceful shutdown of our session
    if tmux has-session -t "$JMUX_SESSION_ID" 2>/dev/null; then
        tmux kill-session -t "$JMUX_SESSION_ID" 2>/dev/null || true
    fi
    
    # Clean up session metadata
    if [ -n "$SESSION_MANAGER" ]; then
        SESSIONS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jmux/sessions"
        rm -f "$SESSIONS_DIR/$JMUX_SESSION_ID.meta" 2>/dev/null || true
    fi
    
    # Nuclear option: kill any tmux processes that might be stuck
    local tmux_pids="$(pgrep -f "tmux.*$JMUX_SESSION_ID" 2>/dev/null || true)"
    if [ -n "$tmux_pids" ]; then
        echo "$tmux_pids" | xargs kill 2>/dev/null || true
        sleep 0.1
        echo "$tmux_pids" | xargs kill -9 2>/dev/null || true
    fi
    
    # Clean up all cache files and lock files
    rm -f /tmp/jmux_files_cache /tmp/jmux_cache_pid /tmp/jmux_main_pid
    rm -f "$JMUX_PID_FILE" "/tmp/jmux_cleanup_$$"
    rm -f /tmp/jmux_session_*.pid 2>/dev/null || true
    rm -f /tmp/jmux_cache_script_*.sh 2>/dev/null || true
    
    echo "jmux session cleaned up successfully."
    exit "$exit_code"
}

# Enhanced signal traps for comprehensive cleanup
trap 'cleanup 130 "SIGINT"' INT       # Ctrl+C
trap 'cleanup 143 "SIGTERM"' TERM     # Termination signal
trap 'cleanup 1 "SIGHUP"' HUP         # Hangup (terminal closed)
trap 'cleanup 2 "SIGQUIT"' QUIT       # Quit signal
trap 'cleanup 0 "EXIT"' EXIT          # Normal exit

# Create PID file for tracking
echo "$$" > "$JMUX_PID_FILE"
echo "$$" > "/tmp/jmux_main_pid"

# Configuration paths
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"
RANGER_TEMP="$CONFIG_BASE/ranger_config"
NVIM_TEMP="$CONFIG_BASE/nvim_config"

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    . "$SCRIPT_DIR/config.sh"
else
    # Default values if config not found
    RANGER_FOCUSED_RATIO=40
    NVIM_FOCUSED_RATIO=20
fi

# Export variables for nvim environment access
export RANGER_FOCUSED_RATIO
export NVIM_FOCUSED_RATIO

# Create config directories
mkdir -p "$RANGER_TEMP" "$NVIM_TEMP" "$CONFIG_BASE/lazygit"

# Copy script files from the jmux installation
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if running from installed location or development location
if [ -d "$SCRIPT_DIR/jmux-scripts" ]; then
    # Running from installed location (/usr/local/bin)
    SCRIPTS_SOURCE="$SCRIPT_DIR/jmux-scripts"
    CONFIG_SOURCE="$SCRIPT_DIR/jmux-config"
else
    # Running from development location
    SCRIPTS_SOURCE="$SCRIPT_DIR/scripts"
    CONFIG_SOURCE="$SCRIPT_DIR/config"
fi

# Copy buffer management script
cp "$SCRIPTS_SOURCE/buffer_manager.lua" "$CONFIG_BASE/"

# Copy all scripts
cp "$SCRIPTS_SOURCE/fuzzy_finder.sh" "$CONFIG_BASE/"
cp "$SCRIPTS_SOURCE/git_commit_preview.sh" "$CONFIG_BASE/"
cp "$SCRIPTS_SOURCE/git_file_breakdown.sh" "$CONFIG_BASE/"
cp "$SCRIPTS_SOURCE/git_log_viewer.sh" "$CONFIG_BASE/"
cp "$SCRIPTS_SOURCE/settings_menu.sh" "$CONFIG_BASE/"
cp "$SCRIPTS_SOURCE/tabbed_terminal.sh" "$CONFIG_BASE/"

# Copy lazygit config
mkdir -p "$CONFIG_BASE/lazygit"
cp "$CONFIG_SOURCE/lazygit.yml" "$CONFIG_BASE/lazygit/config.yml"

# Ranger config - use envsubst to substitute variables
cat > "$RANGER_TEMP/rc.conf" <<EOF
# Hide preview panel completely
set preview_files false
set preview_directories false
set show_hidden false

# Default colorscheme (will be overridden by saved settings)
set colorscheme default

# Use 3 columns with files taking most space
set column_ratios 1,1,2

# Enable mouse support
set mouse_enabled true

# Prioritize filename over extension when truncating
set dirname_in_tabs true
set unicode_ellipsis true
set show_selection_in_titlebar false

# Open files with Enter key - create nvim pane if needed, or open in existing buffer
# Auto-switch behavior will be set based on JMUX_AUTO_SWITCH setting below
ENTER_MAPPING_PLACEHOLDER
unmap l
# Let q work normally (quit ranger), wrapper will handle cleanup
# Disable right arrow from opening files - only allow directory navigation
map <right> eval fm.cd(fm.thisfile.path) if fm.thisfile.is_directory else None

RESTRICT_NAV_PLACEHOLDER

# Switch between panes with Tab (toggle between ranger and nvim)
map <TAB> shell tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%

# Alternative pane switching keys (F1/F2) for backup
map <F1> shell tmux select-pane -t 0; tmux resize-pane -t 0 -x ${RANGER_FOCUSED_RATIO}%%
map <F2> shell tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%

# Open lazygit in popup with :g - run in background to avoid terminal interference
alias g shell tmux display-popup -w 90%% -h 90%% -E 'XDG_CONFIG_HOME="$CONFIG_BASE" lazygit' &

# Open interactive git log with branch graph in popup with :gl
alias gl shell tmux display-popup -w 90%% -h 90%% -E '$CONFIG_BASE/git_log_viewer.sh' &

# Fuzzy file finder with Ctrl+p (VSCode style) - use cached file list
map <C-p> shell tmux display-popup -w 80%% -h 60%% -E '$CONFIG_BASE/fuzzy_finder.sh "%d"' &

# Settings menu with :s  
alias s shell tmux display-popup -w 60%% -h 70%% -E "$CONFIG_BASE/settings_menu.sh" &

# Tabbed terminal with :t
alias t shell tmux display-popup -w 90%% -h 80%% -E "$CONFIG_BASE/tabbed_terminal.sh '%d'"

# Reload config with Ctrl+R (for settings changes)
map <C-r> eval fm.source(fm.confpath('rc.conf'))

# :quit will work normally, wrapper handles cleanup
EOF

# Apply saved settings to ranger config
SETTINGS_FILE="$CONFIG_BASE/settings"
if [ -f "$SETTINGS_FILE" ]; then
    # Load settings
    . "$SETTINGS_FILE"
    
    # Apply ranger theme if set
    if [ -n "$JMUX_RANGER_THEME" ]; then
        sed -i "s/set colorscheme .*/set colorscheme $JMUX_RANGER_THEME/" "$RANGER_TEMP/rc.conf"
    fi
    
    # Apply hidden files setting if set
    if [ -n "$JMUX_SHOW_HIDDEN" ]; then
        sed -i "s/set show_hidden .*/set show_hidden $JMUX_SHOW_HIDDEN/" "$RANGER_TEMP/rc.conf"
    fi
    
    # Apply preview setting if set
    if [ -n "$JMUX_SHOW_PREVIEW" ]; then
        sed -i "s/set preview_files .*/set preview_files $JMUX_SHOW_PREVIEW/" "$RANGER_TEMP/rc.conf"
        sed -i "s/set preview_directories .*/set preview_directories $JMUX_SHOW_PREVIEW/" "$RANGER_TEMP/rc.conf"
    fi
fi

# Apply auto-switch to nvim setting (default: true)
AUTO_SWITCH_SETTING="${JMUX_AUTO_SWITCH:-true}"

# Apply directory restriction setting (default: true)
RESTRICT_DIRECTORY="${JMUX_RESTRICT_NAVIGATION:-true}"

# Create the appropriate Enter command and append it to ranger config
if [ "$AUTO_SWITCH_SETTING" = "true" ]; then
    # Create auto-switch helper script
    cat > "$CONFIG_BASE/enter_helper.sh" << 'ENTER_EOF'
#!/bin/bash

# Fast path-cached sourcing of session utils
UTILS_CACHE_FILE="/tmp/jmux_utils_path_$$"

# Skip sourcing if functions already exist
if ! command -v get_jmux_session >/dev/null 2>&1; then
    # Try cached path first
    if [ -f "$UTILS_CACHE_FILE" ]; then
        CACHED_PATH="$(cat "$UTILS_CACHE_FILE")"
        if [ -f "$CACHED_PATH" ] && source "$CACHED_PATH" 2>/dev/null; then
            # Cache hit - sourced successfully
            :
        else
            # Cache miss - remove stale cache
            rm -f "$UTILS_CACHE_FILE"
        fi
    fi
    
    # If still not loaded, do full search and cache result
    if ! command -v get_jmux_session >/dev/null 2>&1; then
        POSSIBLE_PATHS=(
            "/usr/local/bin/jmux-scripts/jmux_session_utils.sh"
            "$HOME/Documents/jmux/scripts/jmux_session_utils.sh"
            "$(dirname "$0")/../scripts/jmux_session_utils.sh"
            "$(dirname "$0")/jmux_session_utils.sh"
        )
        
        # Add jmux-relative paths if available
        if command -v jmux >/dev/null 2>&1; then
            JMUX_DIR="$(dirname "$(readlink -f "$(which jmux)" 2>/dev/null || which jmux)" 2>/dev/null)"
            [ -n "$JMUX_DIR" ] && POSSIBLE_PATHS+=("$JMUX_DIR/scripts/jmux_session_utils.sh" "$JMUX_DIR/../scripts/jmux_session_utils.sh")
        fi
        
        for UTILS_PATH in "${POSSIBLE_PATHS[@]}"; do
            if [ -f "$UTILS_PATH" ] && source "$UTILS_PATH" 2>/dev/null; then
                # Cache the successful path
                echo "$UTILS_PATH" > "$UTILS_CACHE_FILE"
                break
            fi
        done
        
        # Verify sourcing worked
        command -v get_jmux_session >/dev/null 2>&1 || { echo "Error: Could not find jmux_session_utils.sh" >&2; exit 1; }
    fi
fi
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
    chmod +x "$CONFIG_BASE/enter_helper.sh"
    echo "map <Enter> shell \$HOME/.config/jmux/enter_helper.sh %p %d" >> "$RANGER_TEMP/rc.conf"
else
    # Create no-switch helper script
    cat > "$CONFIG_BASE/enter_helper_noswitch.sh" << 'ENTER_EOF'
#!/bin/bash

# Fast path-cached sourcing of session utils
UTILS_CACHE_FILE="/tmp/jmux_utils_path_$$"

# Skip sourcing if functions already exist
if ! command -v get_jmux_session >/dev/null 2>&1; then
    # Try cached path first
    if [ -f "$UTILS_CACHE_FILE" ]; then
        CACHED_PATH="$(cat "$UTILS_CACHE_FILE")"
        if [ -f "$CACHED_PATH" ] && source "$CACHED_PATH" 2>/dev/null; then
            # Cache hit - sourced successfully
            :
        else
            # Cache miss - remove stale cache
            rm -f "$UTILS_CACHE_FILE"
        fi
    fi
    
    # If still not loaded, do full search and cache result
    if ! command -v get_jmux_session >/dev/null 2>&1; then
        POSSIBLE_PATHS=(
            "/usr/local/bin/jmux-scripts/jmux_session_utils.sh"
            "$HOME/Documents/jmux/scripts/jmux_session_utils.sh"
            "$(dirname "$0")/../scripts/jmux_session_utils.sh"
            "$(dirname "$0")/jmux_session_utils.sh"
        )
        
        # Add jmux-relative paths if available
        if command -v jmux >/dev/null 2>&1; then
            JMUX_DIR="$(dirname "$(readlink -f "$(which jmux)" 2>/dev/null || which jmux)" 2>/dev/null)"
            [ -n "$JMUX_DIR" ] && POSSIBLE_PATHS+=("$JMUX_DIR/scripts/jmux_session_utils.sh" "$JMUX_DIR/../scripts/jmux_session_utils.sh")
        fi
        
        for UTILS_PATH in "${POSSIBLE_PATHS[@]}"; do
            if [ -f "$UTILS_PATH" ] && source "$UTILS_PATH" 2>/dev/null; then
                # Cache the successful path
                echo "$UTILS_PATH" > "$UTILS_CACHE_FILE"
                break
            fi
        done
        
        # Verify sourcing worked
        command -v get_jmux_session >/dev/null 2>&1 || { echo "Error: Could not find jmux_session_utils.sh" >&2; exit 1; }
    fi
fi
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
    chmod +x "$CONFIG_BASE/enter_helper_noswitch.sh"
    echo "map <Enter> shell \$HOME/.config/jmux/enter_helper_noswitch.sh %p %d" >> "$RANGER_TEMP/rc.conf"
fi

# Apply directory restriction if enabled
if [ "$RESTRICT_DIRECTORY" = "true" ]; then
    cat >> "$RANGER_TEMP/rc.conf" << 'RESTRICT_EOF'

# Restrict navigation to stay within the project directory
# Override keys that would navigate to parent directories - only allow if parent is within work dir
map h eval fm.move(left=1) if '$WORK_DIR' in os.path.abspath(os.path.join(fm.thisdir.path, '..')) else None
map <left> eval fm.move(left=1) if '$WORK_DIR' in os.path.abspath(os.path.join(fm.thisdir.path, '..')) else None
map <backspace> eval fm.move(left=1) if '$WORK_DIR' in os.path.abspath(os.path.join(fm.thisdir.path, '..')) else None
RESTRICT_EOF
    # Replace placeholder with actual work dir
    sed -i "s|\$WORK_DIR|$WORK_DIR|g" "$RANGER_TEMP/rc.conf"
fi

# Remove the placeholder lines
sed -i '/ENTER_MAPPING_PLACEHOLDER/d' "$RANGER_TEMP/rc.conf"
sed -i '/RESTRICT_NAV_PLACEHOLDER/d' "$RANGER_TEMP/rc.conf"

# Nvim config
cat > "$NVIM_TEMP/init.lua" <<'EOF'
-- Load modular buffer management
dofile(vim.fn.expand('$HOME/.config/jmux/buffer_manager.lua'))

-- Load saved theme from settings
local settings_file = vim.fn.expand('$HOME/.config/jmux/settings')
if vim.fn.filereadable(settings_file) == 1 then
    local settings = {}
    for line in io.lines(settings_file) do
        local key, value = line:match('(%w+)="([^"]*)"')
        if key and value then
            settings[key] = value
        end
    end
    if settings.JMUX_THEME then
        vim.cmd('colorscheme ' .. settings.JMUX_THEME)
    end
end

-- Check nvim version once at the start
local modern_nvim = vim.fn.has('nvim-0.7') == 1

-- Disable Ctrl+Q terminal control
vim.cmd('silent! unmap <C-q>')
vim.cmd('set t_ku=<Esc>[A')

-- Enable mouse support
vim.opt.mouse = 'a'
vim.opt.mousefocus = true

-- Disable tab displays - we'll use buffers instead
vim.opt.showtabline = 0

-- Override :q to switch to previous buffer instead of closing
vim.cmd([[
  command! -bang Q call QuitBuffer(<bang>0)
  cnoreabbrev <expr> q (getcmdtype() is# ':' && getcmdline() is# 'q') ? 'Q' : 'q'
  cnoreabbrev <expr> quit (getcmdtype() is# ':' && getcmdline() is# 'quit') ? 'Q' : 'quit'
]])

vim.cmd([[
  function! QuitBuffer(force)
    " Get list of valid buffers (exclude buffer list)
    let valid_buffers = []
    for buf in range(1, bufnr('$'))
      if bufexists(buf) && buflisted(buf)
        let name = bufname(buf)
        if name != '' && name !~ 'BufferList$'
          call add(valid_buffers, buf)
        endif
      endif
    endfor
    
    " If more than one valid buffer, switch to another and close current
    if len(valid_buffers) > 1
      " Find a different buffer to switch to (not current)
      let current = bufnr('%')
      let next_buf = -1
      for buf in valid_buffers
        if buf != current
          let next_buf = buf
          break
        endif
      endfor
      
      if next_buf != -1
        execute 'buffer ' . next_buf
        if a:force
          execute 'bdelete! ' . current
        else
          execute 'bdelete ' . current
        endif
        " Refresh the buffer list display
        lua update_buffer_list()
      endif
    else
      " Last buffer, close nvim
      if a:force
        qall!
      else
        qall
      endif
    endif
  endfunction
]])

-- Setup buffer management system
setup_buffer_management()

-- Buffer navigation keybinds
if modern_nvim then
  -- Modern nvim (0.7+) with vim.keymap.set
  vim.keymap.set('n', '<Tab>', function()
    vim.fn.system("tmux select-pane -t 0 && tmux resize-pane -t 0 -x " .. os.getenv("RANGER_FOCUSED_RATIO") .. "%")
  end, { noremap = true, silent = true })
  
  -- Alternative F1 key for terminals that don't support Ctrl+Tab
  vim.keymap.set('n', '<F1>', function()
    vim.fn.system("tmux select-pane -t 0 && tmux resize-pane -t 0 -x " .. os.getenv("RANGER_FOCUSED_RATIO") .. "%")
  end, { noremap = true, silent = true })
  
  -- Buffer switching with Ctrl+n/m (next/previous) - skip buffer list
  vim.keymap.set('n', '<C-n>', function() cycle_buffers(1) end, { noremap = true, silent = true })
  vim.keymap.set('n', '<C-m>', function() cycle_buffers(-1) end, { noremap = true, silent = true })
  
  -- Fuzzy file finder with Ctrl+p (VSCode style) - use cached file list
  vim.keymap.set('n', '<C-p>', function()
    local config_base = vim.fn.expand("$HOME/.config/jmux")
    vim.fn.system("tmux display-popup -w 80% -h 60% -E '" .. config_base .. "/fuzzy_finder.sh \"" .. vim.fn.getcwd() .. "\"' &")
  end, { noremap = true, silent = true })
  
  -- Quick buffer list toggle with Ctrl+b
  vim.keymap.set('n', '<C-b>', function()
    local buflist_win = find_buffer_list_window()
    if buflist_win then
      vim.api.nvim_win_close(buflist_win, false)
    else
      show_buffer_list()
    end
  end, { noremap = true, silent = true })
else
  -- Older nvim versions  
  vim.cmd('nnoremap <silent> <Tab> :lua vim.fn.system("tmux select-pane -t 0 && tmux resize-pane -t 0 -x " .. os.getenv("RANGER_FOCUSED_RATIO") .. "%")<CR>')
  vim.cmd('nnoremap <silent> <F1> :lua vim.fn.system("tmux select-pane -t 0 && tmux resize-pane -t 0 -x " .. os.getenv("RANGER_FOCUSED_RATIO") .. "%")<CR>')
  vim.cmd('nnoremap <silent> <C-n> :lua cycle_buffers(1)<CR>')
  vim.cmd('nnoremap <silent> <C-m> :lua cycle_buffers(-1)<CR>')
  vim.cmd([[nnoremap <silent> <C-p> :lua local config_base = vim.fn.expand("$HOME/.config/jmux"); vim.fn.system("tmux display-popup -w 80% -h 60% -E '" .. config_base .. "/fuzzy_finder.sh \"" .. vim.fn.getcwd() .. "\"'")<CR>]])
  vim.cmd('nnoremap <silent> <C-b> :lua if find_buffer_list_window() then vim.api.nvim_win_close(find_buffer_list_window(), false) else show_buffer_list() end<CR>')
end
EOF

# Make all copied scripts executable
chmod +x "$CONFIG_BASE"/*.sh

# Clean up any orphaned processes before starting
cleanup_before_start() {
    # Clean up any orphaned jmux processes
    pkill -f "jmux_files_cache" 2>/dev/null || true
    
    # Clean up old PID files (older than 1 hour)
    find /tmp -name "jmux_session_*.pid" -mmin +60 -delete 2>/dev/null || true
    
    # Clean up stale session metadata
    "$SESSION_MANAGER" cleanup-stale 2>/dev/null || true
}

cleanup_before_start

# Create a wrapper script that ensures cleanup on ranger exit
WRAPPER_SCRIPT="/tmp/jmux_wrapper_${JMUX_SESSION_ID##*-}.sh"
cat > "$WRAPPER_SCRIPT" << 'WRAPPER_EOF'
#!/bin/bash
cleanup_on_exit() {
    echo "Ranger exited, cleaning up..."
    SESSION_ID="JMUX_SESSION_ID_PLACEHOLDER"
    tmux kill-session -t "$SESSION_ID" 2>/dev/null || true
    pkill -f "jmux_files_cache" 2>/dev/null || true
    rm -f /tmp/jmux_*"${SESSION_ID##*-}"* 2>/dev/null || true
    exit 0
}
trap cleanup_on_exit EXIT INT TERM
WRAPPER_EOF

# Replace placeholder with actual session ID
sed -i "s/JMUX_SESSION_ID_PLACEHOLDER/$JMUX_SESSION_ID/g" "$WRAPPER_SCRIPT"
echo "cd '$WORK_DIR' && ranger --confdir='$RANGER_TEMP'" >> "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

# Start tmux session with the wrapper
tmux new-session -d -s "$JMUX_SESSION_ID" "bash $WRAPPER_SCRIPT"
tmux rename-window -t "$JMUX_SESSION_ID" "jmux - $(basename "$WORK_DIR")"

# Pre-cache file list for faster fzf startup with parent process monitoring
CACHE_WINDOW_NAME="fzf-cache"
if ! tmux list-windows -t "$JMUX_SESSION_ID" | grep -q "$CACHE_WINDOW_NAME"; then
    tmux new-window -t "$JMUX_SESSION_ID" -n "$CACHE_WINDOW_NAME" -d
    tmux send-keys -t "$JMUX_SESSION_ID:$CACHE_WINDOW_NAME" "cd '$WORK_DIR'" Enter
    # Create cache script with proper PID tracking
    CACHE_SCRIPT="/tmp/jmux_cache_script_${JMUX_SESSION_ID##*-}.sh"
    cat > "$CACHE_SCRIPT" << EOF
#!/bin/bash
PARENT_PID=$$
CACHE_PID_FILE="/tmp/jmux_cache_pid_${JMUX_SESSION_ID##*-}"
CACHE_FILE="/tmp/jmux_files_cache_${JMUX_SESSION_ID##*-}"
echo \$\$ > "\$CACHE_PID_FILE"
while kill -0 \$PARENT_PID 2>/dev/null; do 
    find . -type f -not -path '*/.*' | sed 's|^\./||' > "\$CACHE_FILE" 2>/dev/null
    sleep 10
done
# Parent died, clean up and exit
rm -f "\$CACHE_PID_FILE" "\$CACHE_FILE" "$CACHE_SCRIPT"
tmux kill-session -t "$JMUX_SESSION_ID" 2>/dev/null || true
EOF
    chmod +x "$CACHE_SCRIPT"
    tmux send-keys -t "$JMUX_SESSION_ID:$CACHE_WINDOW_NAME" "bash $CACHE_SCRIPT" Enter
fi

# Enable mouse mode for better pane interaction
tmux set-option -g mouse on
tmux set-option -g focus-events on

# Set up session hooks for proper cleanup
tmux set-hook -t "$JMUX_SESSION_ID" session-closed 'run-shell "pkill -f \"find.*jmux_files_cache\"; rm -f /tmp/jmux_*"'

# Focus on ranger window initially  
tmux select-window -t "$JMUX_SESSION_ID:dev"
tmux select-pane -t 0

# Show session info before attaching
echo "Starting jmux session: $JMUX_SESSION_ID"
echo "Working directory: $WORK_DIR"
echo "Use 'jmux list' to see all active sessions"
echo ""

# Attach to the session and handle cleanup when it ends
if tmux has-session -t "$JMUX_SESSION_ID" 2>/dev/null; then
    # Disable the EXIT trap temporarily to avoid double cleanup
    trap - EXIT
    
    # Attach to session - this will block until session ends
    tmux attach-session -t "$JMUX_SESSION_ID"
    
    # When we get here, the session has ended naturally
    # Re-enable cleanup for any remaining processes
    trap cleanup INT TERM
    cleanup
else
    echo "Error: Failed to create tmux session"
    exit 1
fi
