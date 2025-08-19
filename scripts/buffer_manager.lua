-- Buffer management for jmux nvim
-- Handles buffer list display, navigation, and history

-- Global buffer history
vim.g.buffer_history = vim.g.buffer_history or {}

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
  
  -- Force redraw of the buffer list window
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

-- Setup buffer management
function setup_buffer_management()
  local modern_nvim = vim.fn.has('nvim-0.7') == 1
  
  if modern_nvim then
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
  
  -- Add command to manually show buffer list
  if modern_nvim then
    vim.api.nvim_create_user_command('Buffers', show_buffer_list, {})
  else
    vim.cmd('command! Buffers lua show_buffer_list()')
  end
end