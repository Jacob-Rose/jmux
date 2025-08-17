#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RANGER_TEMP="$SCRIPT_DIR/ranger_temp_config"
NVIM_TEMP="$SCRIPT_DIR/nvim_temp_config"

# Ranger config
mkdir -p "$RANGER_TEMP"
cat > "$RANGER_TEMP/rc.conf" <<'EOF'
# Completely disable default file opening
map <Enter> shell tmux send-keys -t 1 Escape ":e %p" Enter
unmap l

# Switch between panes with Tab
map <TAB> shell tmux select-pane -t 1
map <S-TAB> shell tmux select-pane -t 0

# Quit key: q  
map q shell tmux kill-session -t ide
EOF

# Nvim config
mkdir -p "$NVIM_TEMP"
cat > "$NVIM_TEMP/init.lua" <<'EOF'
-- Custom config loaded indicator
print("Custom nvim config loaded!")

-- Disable Ctrl+Q terminal control
vim.cmd('silent! unmap <C-q>')
vim.cmd('set t_ku=<Esc>[A')

vim.keymap.set('n', '<leader>q', function()
  print("Leader+q pressed - quitting nvim")
  vim.cmd('qa!')
end, { noremap = true, silent = true })

vim.keymap.set('n', '<C-q>', function()
  print("Ctrl+q pressed - quitting nvim")
  vim.fn.system("tmux kill-session -t ide")
end, { noremap = true, silent = true })

-- Switch between panes with Tab
vim.keymap.set('n', '<Tab>', function()
  vim.fn.system("tmux select-pane -t 0")
end, { noremap = true, silent = true })
EOF

# Start tmux session with ranger in the first pane
tmux new-session -d -s ide "ranger --confdir='$RANGER_TEMP'"
tmux rename-window 'dev'

# Split window - ranger gets 60%, nvim 40%
tmux split-window -h -p 40 "nvim -u $NVIM_TEMP/init.lua"

# Focus on ranger pane initially
tmux select-pane -t 0

# Attach
tmux attach-session -t ide
