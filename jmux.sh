#!/bin/bash

# jmux: A tmux-based IDE with ranger and nvim
# Usage: jmux [directory]
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

# Set working directory (use argument or current directory)
WORK_DIR="${1:-$(pwd)}"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"  # Get absolute path

# Check for stale jmux sessions and offer to clean them up
check_stale_sessions() {
    local stale_sessions="$(tmux list-sessions 2>/dev/null | grep "^ide:" || true)"
    if [ -n "$stale_sessions" ]; then
        echo "Warning: Found existing jmux session(s):"
        echo "$stale_sessions"
        echo ""
        read -p "Clean up existing session(s)? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tmux kill-session -t ide 2>/dev/null || true
            echo "Existing session cleaned up."
        else
            echo "Proceeding with existing session (may cause conflicts)..."
        fi
    fi
}

# Only check for stale sessions in interactive mode
if [ -t 0 ]; then
    check_stale_sessions
fi

# Store session info for cleanup tracking
JMUX_SESSION_ID="jmux-$$"  # Use PID for unique session ID
JMUX_PID_FILE="/tmp/jmux_session_$$.pid"

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
    # First try graceful shutdown
    if tmux has-session -t ide 2>/dev/null; then
        tmux kill-session -t ide 2>/dev/null || true
    fi
    
    # Also check for any sessions with our PID pattern
    if tmux has-session -t "$JMUX_SESSION_ID" 2>/dev/null; then
        tmux kill-session -t "$JMUX_SESSION_ID" 2>/dev/null || true
    fi
    
    # Nuclear option: kill any tmux processes that might be stuck
    local tmux_pids="$(pgrep -f "tmux.*ide" 2>/dev/null || true)"
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

# Create the appropriate Enter command and append it to ranger config
if [ "$AUTO_SWITCH_SETTING" = "true" ]; then
    # Auto-switch to nvim after opening file
    echo "map <Enter> shell if tmux list-panes -t ide:dev | grep -q \"1:\"; then tmux send-keys -t ide:dev.1 Escape \":lua open_file_in_main_editor('\$(readlink -f %p)')\" Enter; tmux select-window -t ide:dev; tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%; else tmux split-window -t ide:dev -h -p 60 \"cd '%d' && nvim -u '$NVIM_TEMP/init.lua' '\$(readlink -f %p)'\"; tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%; fi" >> "$RANGER_TEMP/rc.conf"
else
    # Stay in ranger after opening file
    echo "map <Enter> shell if tmux list-panes -t ide:dev | grep -q \"1:\"; then tmux send-keys -t ide:dev.1 Escape \":lua open_file_in_main_editor('\$(readlink -f %p)')\" Enter; else tmux split-window -t ide:dev -h -p 60 \"cd '%d' && nvim -u '$NVIM_TEMP/init.lua' '\$(readlink -f %p)'\"; tmux select-pane -t 0; fi" >> "$RANGER_TEMP/rc.conf"
fi

# Remove the placeholder line
sed -i '/ENTER_MAPPING_PLACEHOLDER/d' "$RANGER_TEMP/rc.conf"

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

# Clean up any existing sessions before starting
cleanup_existing_sessions() {
    # Kill any existing IDE sessions
    tmux kill-session -t ide 2>/dev/null || true
    tmux kill-session -t "$JMUX_SESSION_ID" 2>/dev/null || true
    
    # Clean up any orphaned jmux processes
    pkill -f "jmux_files_cache" 2>/dev/null || true
    
    # Clean up old PID files (older than 1 hour)
    find /tmp -name "jmux_session_*.pid" -mmin +60 -delete 2>/dev/null || true
}

cleanup_existing_sessions

# Create a wrapper script that ensures cleanup on ranger exit
cat > "/tmp/jmux_wrapper_$$.sh" << 'WRAPPER_EOF'
#!/bin/bash
cleanup_on_exit() {
    echo "Ranger exited, cleaning up..."
    tmux kill-session -t ide 2>/dev/null || true
    pkill -f "jmux_files_cache" 2>/dev/null || true
    rm -f /tmp/jmux_* 2>/dev/null || true
    exit 0
}
trap cleanup_on_exit EXIT INT TERM
WRAPPER_EOF

echo "cd '$WORK_DIR' && ranger --confdir='$RANGER_TEMP'" >> "/tmp/jmux_wrapper_$$.sh"
chmod +x "/tmp/jmux_wrapper_$$.sh"

# Start tmux session with the wrapper
tmux new-session -d -s ide "bash /tmp/jmux_wrapper_$$.sh"
tmux rename-window 'dev'

# Pre-cache file list for faster fzf startup with parent process monitoring
if ! tmux list-windows -t ide | grep -q 'fzf-cache'; then
    tmux new-window -t ide -n 'fzf-cache' -d
    tmux send-keys -t ide:fzf-cache "cd '$WORK_DIR'" Enter
    # Create cache script with proper PID tracking
    cat > "/tmp/jmux_cache_script_$$.sh" << EOF
#!/bin/bash
PARENT_PID=$$
echo \$\$ > /tmp/jmux_cache_pid
while kill -0 \$PARENT_PID 2>/dev/null; do 
    find . -type f -not -path '*/.*' | sed 's|^\./||' > /tmp/jmux_files_cache 2>/dev/null
    sleep 10
done
# Parent died, clean up and exit
rm -f /tmp/jmux_cache_pid /tmp/jmux_files_cache /tmp/jmux_cache_script_$$.sh
tmux kill-session -t ide 2>/dev/null || true
EOF
    chmod +x "/tmp/jmux_cache_script_$$.sh"
    tmux send-keys -t ide:fzf-cache "bash /tmp/jmux_cache_script_$$.sh" Enter
fi

# Enable mouse mode for better pane interaction
tmux set-option -g mouse on
tmux set-option -g focus-events on

# Set up session hooks for proper cleanup
tmux set-hook -t ide session-closed 'run-shell "pkill -f \"find.*jmux_files_cache\""'

# Focus on ranger window initially  
tmux select-window -t ide:dev
tmux select-pane -t 0

# Attach to the session and handle cleanup when it ends
if tmux has-session -t ide 2>/dev/null; then
    # Disable the EXIT trap temporarily to avoid double cleanup
    trap - EXIT
    
    # Attach to session - this will block until session ends
    tmux attach-session -t ide
    
    # When we get here, the session has ended naturally
    # Re-enable cleanup for any remaining processes
    trap cleanup INT TERM
    cleanup
else
    echo "Error: Failed to create tmux session"
    exit 1
fi
