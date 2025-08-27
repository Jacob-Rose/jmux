# Textual jmux

🚀 **A modern Python/Textual file manager - Perfect for remote development via SSH!**

## 🌐 **Remote Development Ready**

**Why Textual jmux is ideal for remote work:**
- ✅ **SSH Native** - Works flawlessly over SSH connections with full mouse support
- ✅ **No X11 Required** - Pure terminal, no GUI dependencies or forwarding needed
- ✅ **Lightweight** - Single Python dependency, runs on any system with Python 3.8+
- ✅ **Tmux Integration** - Seamlessly opens nvim in new panes, just like original jmux
- ✅ **Modern UX** - Beautiful TUI with mouse support even over slow connections

## 🎯 **Features**

- [x] **File browser** with full mouse and keyboard navigation
- [x] **Double-click file opening** - Finally works! (impossible in ranger)
- [x] **Live file preview** in right panel
- [x] **Vim-style commands** - `:q`, `:o filename`, `:e filename`
- [x] **Tmux integration** - `Ctrl+O` opens files in new nvim panes
- [x] **SSH-optimized** - Works perfectly over remote connections
- [ ] Settings menu and themes
- [ ] Git integration
- [ ] Fuzzy file finder

## 🖥️ **Remote Installation (SSH)**

### Quick Setup on Remote Server:
```bash
# SSH into your remote machine
ssh user@remote-server

# Install textual (user-local, no sudo needed)
pip3 install --user textual

# Clone or copy the textual-jmux folder
git clone <repo> && cd textual-jmux
# OR: scp -r textual-jmux/ user@remote-server:~/

# Run immediately
python3 main.py
```

### One-liner for existing Python environments:
```bash
pip3 install textual && python3 main.py
```

## 🎮 **Usage**

### Basic Navigation:
- **Mouse**: Click files, scroll, double-click to open
- **Keyboard**: Arrow keys, Enter to select
- **`:` commands**: `:q` (quit), `:o filename` (open), `:e filename` (edit in nvim)

### Remote Workflow:
```bash
# 1. SSH into remote machine
ssh dev-server

# 2. Navigate to project directory
cd /path/to/project

# 3. Start textual jmux
python3 ~/textual-jmux/main.py

# 4. Browse files, double-click to preview
# 5. Press Ctrl+O to open in nvim (new tmux pane)
# 6. Use :q to quit back to shell
```

## 🔧 **Why Python/Textual for Remote Development?**

**Advantages over traditional tools:**
- **Better than nano/vim alone**: Rich file browser + preview
- **Better than ranger**: Double-click support, modern UI, easier customization
- **Better than GUI tools**: No X11/VNC overhead, works on any SSH connection
- **Better than web IDEs**: Full terminal integration, your familiar environment

**Technical Benefits:**
- **Terminal-native**: Uses standard VT100/xterm escape sequences
- **Mouse support**: Works with any modern terminal (iTerm, Terminal, PuTTY, etc.)
- **Low bandwidth**: Efficient screen updates, perfect for slow connections
- **No dependencies**: Just Python + textual, available everywhere

## 🏗️ **Architecture**

```
textual-jmux/
├── main.py              # Main application (200+ lines)
├── requirements.txt     # Just: textual>=0.40.0
├── demo.sh             # Demo runner
├── test_files/         # Sample files
└── README.md           # This file
```

## 📱 **Terminal Compatibility**

**Fully tested with:**
- ✅ **SSH clients**: OpenSSH, PuTTY, SecureCRT, Terminus, etc.
- ✅ **Terminals**: iTerm2, Terminal.app, GNOME Terminal, Windows Terminal
- ✅ **Multiplexers**: tmux, screen (tmux integration built-in)
- ✅ **Platforms**: Linux, macOS, WSL, BSD

## 🚀 **Quick Start**

```bash
# Local testing
./demo.sh

# Remote deployment
scp -r textual-jmux/ user@server:~/
ssh user@server 'cd textual-jmux && python3 main.py'
```