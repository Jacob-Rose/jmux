#!/bin/bash

# jmux: A tmux-based IDE with ranger and nvim
# Usage: jmux [directory]

# Set working directory (use argument or current directory)
WORK_DIR="${1:-$(pwd)}"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"  # Get absolute path

# Configuration paths
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"
RANGER_TEMP="$CONFIG_BASE/ranger_config"
NVIM_TEMP="$CONFIG_BASE/nvim_config"

# Create config directories
mkdir -p "$RANGER_TEMP" "$NVIM_TEMP"

# Create shared fuzzy finder script
cat > "$CONFIG_BASE/fuzzy_finder.sh" <<'EOF'
#!/bin/bash
# Shared fuzzy file finder for jmux
# Usage: fuzzy_finder.sh [directory]

SEARCH_DIR="${1:-$(pwd)}"
cd "$SEARCH_DIR"

# Run fzf and open selected file in nvim
SELECTED=$(fzf --preview "cat {}" --height=100%)
if [ -n "$SELECTED" ]; then
    tmux send-keys -t 1 Escape ":e $(readlink -f "$SELECTED")" Enter
fi
EOF

chmod +x "$CONFIG_BASE/fuzzy_finder.sh"

# Ranger config
cat > "$RANGER_TEMP/rc.conf" <<EOF
# Hide preview panel
set preview_files false
set preview_directories false

# Open files with Enter key - create nvim pane if needed, or open in existing buffer
map <Enter> shell if tmux list-panes | grep -q "1:"; then tmux send-keys -t 1 Escape ":e \$(readlink -f %p)" Enter; else tmux split-window -h -p 60 "cd '%d' && nvim -u '$NVIM_TEMP/init.lua' '\$(readlink -f %p)'"; fi
unmap l
unmap q
# Disable right arrow from opening files - only allow directory navigation
map <right> eval fm.cd(fm.thisfile.path) if fm.thisfile.is_directory else None

# Switch between panes with Tab
map <TAB> shell tmux select-pane -t 1
map <S-TAB> shell tmux select-pane -t 0

# Open lazygit in popup with ;g - run in background to avoid terminal interference
map ;g shell tmux display-popup -w 90%% -h 90%% -E lazygit &

# Fuzzy file finder with Ctrl+p (VSCode style) - use shared script
map <C-p> shell tmux display-popup -w 80%% -h 60%% -E '$CONFIG_BASE/fuzzy_finder.sh "%d"' &
EOF

# Nvim config
cat > "$NVIM_TEMP/init.lua" <<'EOF'
-- Disable Ctrl+Q terminal control
vim.cmd('silent! unmap <C-q>')
vim.cmd('set t_ku=<Esc>[A')

-- Enable mouse support
vim.opt.mouse = 'a'
vim.opt.mousefocus = true

-- Disable tab displays - we'll use buffers instead
vim.opt.showtabline = 0

-- Buffer management setup
vim.g.buffer_history = {}

-- Helper function to check if buffer is valid (not buffer list)
function is_valid_buffer(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or not vim.api.nvim_buf_get_option(buf, 'buflisted') then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= '' and not name:match('BufferList$')
end

-- Helper function to get all valid buffers
function get_valid_buffers()
  local valid_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_valid_buffer(buf) then
      table.insert(valid_buffers, buf)
    end
  end
  return valid_buffers
end

-- Helper function to find buffer list window
function find_buffer_list_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):match('BufferList$') then
      return win
    end
  end
  return nil
end

-- Function to update buffer history
function update_buffer_history()
  local current_buf = vim.fn.bufnr('%')
  local history = vim.g.buffer_history or {}
  
  -- Remove current buffer from history if it exists
  for i, buf in ipairs(history) do
    if buf == current_buf then
      table.remove(history, i)
      break
    end
  end
  
  -- Add current buffer to beginning of history
  table.insert(history, 1, current_buf)
  
  -- Keep only last 10 buffers
  if #history > 10 then
    table.remove(history, #history)
  end
  
  vim.g.buffer_history = history
end

-- Show buffer list in vertical split
function show_buffer_list()
  -- Check if buffer list window already exists
  if find_buffer_list_window() then
    return -- Already exists
  end
  
  -- Create vertical split for buffer list
  vim.cmd('vertical 20new BufferList')
  local buf = vim.api.nvim_get_current_buf()
  
  -- Configure buffer list window
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_win_set_option(0, 'number', false)
  vim.api.nvim_win_set_option(0, 'relativenumber', false)
  vim.api.nvim_win_set_option(0, 'wrap', false)
  vim.api.nvim_win_set_option(0, 'cursorline', true)
  
  update_buffer_list()
  
  -- Set up keybindings in buffer list
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>lua goto_selected_buffer()<CR>', {silent = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', '<2-LeftMouse>', '<cmd>lua goto_selected_buffer()<CR>', {silent = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', '<LeftMouse>', '<LeftMouse><cmd>lua goto_selected_buffer()<CR>', {silent = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', {silent = true})
  
  -- Make buffer list focusable but don't auto-focus
  vim.api.nvim_win_set_option(0, 'winfixwidth', true)
  
  -- Go back to main window
  vim.cmd('wincmd p')
end

-- Update buffer list display
function update_buffer_list()
  local buflist_win = find_buffer_list_window()
  if not buflist_win then return end
  
  local buflist_buf = vim.api.nvim_win_get_buf(buflist_win)
  local lines = {'RECENT FILES:', ''}
  local current_buf = vim.fn.bufnr('%')
  
  -- Get list of buffers ordered by history (most recent first)
  local history = vim.g.buffer_history or {}
  local buffers = {}
  
  -- Add buffers in history order
  for _, buf in ipairs(history) do
    if is_valid_buffer(buf) then
      table.insert(buffers, {buf = buf, name = vim.api.nvim_buf_get_name(buf)})
    end
  end
  
  -- Add any buffers not in history (fallback)
  for _, buf in ipairs(get_valid_buffers()) do
    -- Check if already in buffers list
    local already_added = false
    for _, existing in ipairs(buffers) do
      if existing.buf == buf then
        already_added = true
        break
      end
    end
    if not already_added then
      table.insert(buffers, {buf = buf, name = vim.api.nvim_buf_get_name(buf)})
    end
  end
  
  -- Display buffers
  for i, buffer in ipairs(buffers) do
    local filename = vim.fn.fnamemodify(buffer.name, ':t')
    local prefix = (buffer.buf == current_buf) and '▶ ' or '  '
    local is_modified = vim.api.nvim_buf_get_option(buffer.buf, 'modified')
    local modified = is_modified and ' ●' or ''
    table.insert(lines, prefix .. i .. ': ' .. filename .. modified)
  end
  
  if #buffers == 0 then
    table.insert(lines, '  No buffers')
  end
  
  vim.api.nvim_buf_set_option(buflist_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buflist_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buflist_buf, 'modifiable', false)
  
  -- Force redraw of the buffer list window (similar to quit file logic)
  if vim.api.nvim_win_is_valid(buflist_win) then
    vim.api.nvim_win_call(buflist_win, function()
      vim.cmd('redraw')
    end)
  end
end

-- Go to selected buffer
function goto_selected_buffer()
  local line = vim.fn.line('.')
  if line <= 2 then return end -- Skip header lines
  
  local buffers = get_valid_buffers()
  
  local selected_index = line - 2 -- Account for header
  if selected_index <= #buffers then
    vim.cmd('wincmd p') -- Go to main window
    vim.cmd('buffer ' .. buffers[selected_index])
  end
end

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

-- Auto-create buffer list when second file is opened
if vim.fn.has('nvim-0.7') == 1 then
  vim.api.nvim_create_augroup('BufferManagement', { clear = true })
  
  -- Create buffer list when nvim starts
  vim.api.nvim_create_autocmd('VimEnter', {
    group = 'BufferManagement',
    callback = function()
      show_buffer_list()
      update_buffer_list()
    end
  })
  
  -- Only update buffer list on buffer enter (don't create)
  vim.api.nvim_create_autocmd('BufEnter', {
    group = 'BufferManagement',
    callback = function()
      -- Skip if we're in the buffer list itself
      local current_buf_name = vim.api.nvim_buf_get_name(0)
      if current_buf_name:match('BufferList$') then
        return
      end
      
      -- Only update if buffer list exists
      update_buffer_list()
    end
  })
  
  -- Shared callback for text changes
  local function on_text_changed()
    update_buffer_history()
    update_buffer_list()
  end
  
  -- Move buffer to top of history when modified
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = 'BufferManagement',
    callback = on_text_changed
  })
  
  -- Update buffer list when file is saved (remove modified indicator)
  vim.api.nvim_create_autocmd({'BufWritePost', 'BufWrite'}, {
    group = 'BufferManagement',
    callback = function()
      -- Use vim.schedule to ensure the modified flag is updated
      vim.schedule(function()
        update_buffer_list()
      end)
    end
  })
else
  -- Legacy autocmds for nvim 0.6.1
  vim.cmd([[
    augroup BufferManagement
      autocmd!
      autocmd VimEnter * lua show_buffer_list(); update_buffer_list()
      autocmd BufEnter * lua if not vim.api.nvim_buf_get_name(0):match('BufferList$') then update_buffer_list() end
      autocmd TextChanged,TextChangedI * lua update_buffer_history(); update_buffer_list()
      autocmd BufWritePost,BufWrite * lua update_buffer_list()
    augroup END
  ]])
end

-- Function to open fuzzy finder
function open_fuzzy_finder()
  local config_base = vim.fn.expand("$HOME/.config/jmux")
  vim.fn.system("tmux display-popup -w 80% -h 60% -E '" .. config_base .. "/fuzzy_finder.sh \"" .. vim.fn.getcwd() .. "\"' &")
end

-- Function to cycle through valid buffers only (skip buffer list)
function cycle_buffers(direction)
  local valid_buffers = get_valid_buffers()
  
  if #valid_buffers <= 1 then
    return -- Nothing to cycle through
  end
  
  -- Find current buffer index
  local current_buf = vim.fn.bufnr('%')
  local current_index = nil
  for i, buf in ipairs(valid_buffers) do
    if buf == current_buf then
      current_index = i
      break
    end
  end
  
  if not current_index then
    -- Current buffer not in list, go to first valid buffer
    vim.cmd('buffer ' .. valid_buffers[1])
    return
  end
  
  -- Calculate next buffer index
  local next_index = current_index + direction
  if next_index > #valid_buffers then
    next_index = 1
  elseif next_index < 1 then
    next_index = #valid_buffers
  end
  
  -- Switch to next buffer
  vim.cmd('buffer ' .. valid_buffers[next_index])
end

-- Add command to manually show buffer list
if vim.fn.has('nvim-0.7') == 1 then
  vim.api.nvim_create_user_command('Buffers', show_buffer_list, {})
else
  vim.cmd('command! Buffers lua show_buffer_list()')
end

-- Buffer navigation keybinds
if vim.fn.has('nvim-0.7') == 1 then
  -- Modern nvim (0.7+) with vim.keymap.set
  vim.keymap.set('n', '<Tab>', function()
    vim.fn.system("tmux select-pane -t 0")
  end, { noremap = true, silent = true })
  
  -- Buffer switching with Ctrl+n/m (next/previous) - skip buffer list
  vim.keymap.set('n', '<C-n>', function() cycle_buffers(1) end, { noremap = true, silent = true })
  vim.keymap.set('n', '<C-m>', function() cycle_buffers(-1) end, { noremap = true, silent = true })
  
  -- Fuzzy file finder with Ctrl+p (VSCode style) - use shared script
  vim.keymap.set('n', '<C-p>', function()
    local config_base = vim.fn.expand("$HOME/.config/jmux")
    vim.fn.system("tmux display-popup -w 80% -h 60% -E '" .. config_base .. "/fuzzy_finder.sh \"" .. vim.fn.getcwd() .. "\"' &")
  end, { noremap = true, silent = true })
  
  -- Buffer switching with [ and ] (common vim pattern) - skip buffer list
  vim.keymap.set('n', ']b', function() cycle_buffers(1) end, { noremap = true, silent = true })
  vim.keymap.set('n', '[b', function() cycle_buffers(-1) end, { noremap = true, silent = true })
  
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
  vim.cmd('nnoremap <silent> <Tab> :lua vim.fn.system("tmux select-pane -t 0")<CR>')
  vim.cmd('nnoremap <silent> <C-n> :lua cycle_buffers(1)<CR>')
  vim.cmd('nnoremap <silent> <C-m> :lua cycle_buffers(-1)<CR>')
  vim.cmd('nnoremap <silent> <C-p> :lua open_fuzzy_finder()<CR>')
  vim.cmd('nnoremap <silent> ]b :lua cycle_buffers(1)<CR>')
  vim.cmd('nnoremap <silent> [b :lua cycle_buffers(-1)<CR>')
  vim.cmd('nnoremap <silent> <C-b> :lua if find_buffer_list_window() then vim.api.nvim_win_close(find_buffer_list_window(), false) else show_buffer_list() end<CR>')
end
EOF

# Start tmux session with ranger in the first pane
tmux new-session -d -s ide "cd '$WORK_DIR' && ranger --confdir='$RANGER_TEMP'; tmux kill-session -t ide"
tmux rename-window 'dev'

# Enable mouse mode for better pane interaction
tmux set-option -g mouse on
tmux set-option -g focus-events on

# Focus on ranger pane initially
tmux select-pane -t 0

# Attach
tmux attach-session -t ide
