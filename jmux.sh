#!/bin/bash

# jmux: A tmux-based IDE with ranger and nvim
# Usage: jmux [directory]

# Set working directory (use argument or current directory)
WORK_DIR="${1:-$(pwd)}"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"  # Get absolute path

# Cleanup function to kill tmux session and all children
cleanup() {
    echo ""
    echo "Cleaning up jmux session..."
    
    # Kill any background cache process
    if [ -f /tmp/jmux_cache_pid ]; then
        local cache_pid="$(cat /tmp/jmux_cache_pid 2>/dev/null)"
        if [ -n "$cache_pid" ]; then
            kill "$cache_pid" 2>/dev/null || true
        fi
        rm -f /tmp/jmux_cache_pid
    fi
    
    # Kill any remaining find processes for file caching
    pkill -f "find.*jmux_files_cache" 2>/dev/null || true
    
    # Kill the IDE session and all its windows/panes
    if tmux has-session -t ide 2>/dev/null; then
        tmux kill-session -t ide
    fi
    
    # Clean up cache files
    rm -f /tmp/jmux_files_cache
    
    echo "jmux session closed."
    exit 0
}

# Set up signal traps for proper cleanup
trap cleanup INT TERM EXIT

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

# Open files with Enter key - create nvim pane if needed, or open in existing buffer, then focus nvim
map <Enter> shell if tmux list-panes -t ide:dev | grep -q "1:"; then tmux send-keys -t ide:dev.1 Escape ":lua open_file_in_main_editor('\$(readlink -f %p)')" Enter; tmux select-window -t ide:dev; tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%; else tmux split-window -t ide:dev -h -p 60 "cd '%d' && nvim -u '$NVIM_TEMP/init.lua' '\$(readlink -f %p)'"; tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%; fi
unmap l
# Map q to quit ranger and kill the entire jmux session
map q shell tmux kill-session -t ide
# Disable right arrow from opening files - only allow directory navigation
map <right> eval fm.cd(fm.thisfile.path) if fm.thisfile.is_directory else None

# Switch between panes with Tab and resize for focused app
map <TAB> shell tmux select-pane -t 1; tmux resize-pane -t 0 -x ${NVIM_FOCUSED_RATIO}%%
map <S-TAB> shell tmux select-pane -t 0; tmux resize-pane -t 0 -x ${RANGER_FOCUSED_RATIO}%%

# Open lazygit in popup with :g - run in background to avoid terminal interference
alias g shell tmux display-popup -w 90%% -h 90%% -E 'XDG_CONFIG_HOME="$CONFIG_BASE" lazygit' &

# Open interactive git log with branch graph in popup with :gl
alias gl shell tmux display-popup -w 90%% -h 90%% -E '$CONFIG_BASE/git_log_viewer.sh' &

# Fuzzy file finder with Ctrl+p (VSCode style) - use cached file list
map <C-p> shell tmux display-popup -w 80%% -h 60%% -E '$CONFIG_BASE/fuzzy_finder.sh "%d"' &

# Settings menu with :s  
alias s shell tmux display-popup -w 60%% -h 70%% -E "$CONFIG_BASE/settings_menu.sh" &

# Quit jmux entirely with :q
alias quit shell tmux kill-session -t ide
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
  vim.cmd('nnoremap <silent> <C-n> :lua cycle_buffers(1)<CR>')
  vim.cmd('nnoremap <silent> <C-m> :lua cycle_buffers(-1)<CR>')
  vim.cmd([[nnoremap <silent> <C-p> :lua local config_base = vim.fn.expand("$HOME/.config/jmux"); vim.fn.system("tmux display-popup -w 80% -h 60% -E '" .. config_base .. "/fuzzy_finder.sh \"" .. vim.fn.getcwd() .. "\"'")<CR>]])
  vim.cmd('nnoremap <silent> <C-b> :lua if find_buffer_list_window() then vim.api.nvim_win_close(find_buffer_list_window(), false) else show_buffer_list() end<CR>')
end
EOF

# Make all copied scripts executable
chmod +x "$CONFIG_BASE"/*.sh

# Kill existing session if it exists
if tmux has-session -t ide 2>/dev/null; then
    tmux kill-session -t ide
fi

# Start tmux session with ranger in the first pane - exit when ranger exits
tmux new-session -d -s ide "cd '$WORK_DIR' && ranger --confdir='$RANGER_TEMP'; tmux kill-session -t ide"
tmux rename-window 'dev'

# Pre-cache file list for faster fzf startup
if ! tmux list-windows -t ide | grep -q 'fzf-cache'; then
    tmux new-window -t ide -n 'fzf-cache' -d
    tmux send-keys -t ide:fzf-cache "cd '$WORK_DIR'" Enter
    tmux send-keys -t ide:fzf-cache "echo \$\$ > /tmp/jmux_cache_pid; while true; do find . -type f -not -path '*/.*' | sed 's|^\./||' > /tmp/jmux_files_cache 2>/dev/null; sleep 10; done" Enter
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
