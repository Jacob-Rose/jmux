# 🌐 SSH & Remote Development Guide

## Why Textual jmux is Perfect for Remote Work

**The Problem with Remote Development:**
- GUI IDEs require X11 forwarding (slow, complex setup)
- VSCode Remote requires specific server setup
- Traditional terminal tools lack modern UX
- File management over SSH is painful

**Textual jmux Solution:**
- ✅ **Pure terminal** - works with any SSH client
- ✅ **Modern interface** - mouse support, beautiful TUI
- ✅ **Zero setup** - just Python + one dependency
- ✅ **Tmux integration** - seamless editor workflow

## 🚀 Quick Remote Setup

### Method 1: Automated Setup
```bash
# Copy and run setup script
scp remote-setup.sh user@remote-host:~/
ssh user@remote-host './remote-setup.sh'
```

### Method 2: Manual Setup  
```bash
# 1. Copy files to remote
scp -r textual-jmux/ user@remote-host:~/

# 2. SSH in and install
ssh user@remote-host
pip3 install --user textual
cd textual-jmux && python3 main.py
```

### Method 3: One-liner
```bash
ssh user@remote-host 'pip3 install --user textual && git clone <repo> && cd textual-jmux && python3 main.py'
```

## 📋 Remote Requirements

**Minimal Requirements:**
- Python 3.8+ (usually pre-installed)
- pip3 (for textual installation)  
- SSH access
- Terminal with mouse support (most modern terminals)

**Optional Enhancements:**
- tmux (for integrated nvim panes)
- git (for easy updates)
- nvim/vim (for file editing)

**No Requirements:**
- ❌ X11 or GUI forwarding
- ❌ Docker or containers  
- ❌ Root/sudo access
- ❌ Complex server setup

## 🖥️ Terminal Compatibility

### Fully Supported SSH Clients:
- **OpenSSH** (Linux/macOS/WSL) ✅
- **PuTTY** (Windows) ✅  
- **SecureCRT** (Commercial) ✅
- **Terminus** (Modern terminal) ✅
- **VS Code integrated terminal** ✅

### Mouse Support Testing:
```bash
# Test mouse support over SSH
ssh user@remote-host
python3 -c "
import sys
print('Terminal info:')
print(f'TERM: {sys.stdout.isatty()}')  
print('Mouse test: Move cursor and click')
"
```

## 🔧 Tmux Integration

### Automatic Setup:
The app detects tmux automatically:
```bash
# Start tmux session
tmux new-session -d -s dev

# Run textual jmux inside tmux  
python3 main.py

# Ctrl+O opens nvim in new pane automatically
```

### Manual Tmux Commands:
```bash
# Create development session
tmux new-session -s "remote-dev" -d
tmux split-window -h -p 40  # Create right pane for editor
tmux select-pane -t 0       # Focus left pane
tmux send-keys "cd /path/to/project && python3 textual-jmux/main.py" C-m
```

## 🚀 Workflow Examples

### Typical Remote Development Session:
```bash
# 1. SSH to remote server
ssh dev-server

# 2. Start tmux session
tmux new -s work

# 3. Navigate to project
cd /home/user/projects/myapp

# 4. Start textual jmux
python3 ~/textual-jmux/main.py

# 5. Browse files with mouse, double-click to preview
# 6. Press Ctrl+O to open file in nvim (new tmux pane)
# 7. Use :q to return to file browser
# 8. Detach tmux: Ctrl+B, d
# 9. Later: tmux attach -t work
```

### Multi-Project Workflow:
```bash
# Terminal 1: File browser
tmux new -s files
python3 ~/textual-jmux/main.py

# Terminal 2: Main editing  
tmux new -s edit
nvim

# Terminal 3: Running processes
tmux new -s run
npm run dev
```

## 📱 Mobile/Tablet SSH

**Works great with mobile SSH clients:**
- **Termius** (iOS/Android) - Full mouse support
- **iSH** (iOS) - Terminal emulator with Python
- **Termux** (Android) - Full Linux environment
- **JuiceSSH** (Android) - Good terminal support

**Mobile Tips:**
- Enable mouse mode in your SSH client
- Use larger terminal font for touch targets
- Vim commands work well on mobile keyboards

## 🔍 Troubleshooting Remote Issues

### Mouse Not Working:
```bash
# Check terminal capabilities
echo $TERM
infocmp | grep mouse

# Enable mouse in SSH client
# PuTTY: Connection > Data > Terminal-type string: xterm-256color
# iTerm2: Preferences > Profiles > Terminal > Report mouse events
```

### Python/pip Issues:
```bash
# Check Python version
python3 --version

# Install pip if missing
curl https://bootstrap.pypa.io/get-pip.py | python3

# Install textual with verbose output
pip3 install --user --verbose textual
```

### Tmux Integration Issues:
```bash
# Check if in tmux
echo $TMUX

# Test tmux commands
tmux list-sessions
tmux split-window -h 'echo "test"'
```

### Performance Over Slow Connections:
```bash
# Reduce update frequency for slow connections
export TEXTUAL_FPS=10

# Use compression for SSH
ssh -C user@remote-host
```

## 🎯 Advantages Over Alternatives

| Tool | Local GUI | X11 Forward | Web IDE | Textual jmux |
|------|-----------|-------------|---------|--------------|
| **SSH Native** | ❌ | ✅ | ❌ | ✅ |
| **No Setup** | ❌ | ❌ | ❌ | ✅ |
| **Mouse Support** | ✅ | ✅ | ✅ | ✅ |
| **Fast Over SSH** | ❌ | ❌ | ⚠️ | ✅ |
| **Works Anywhere** | ❌ | ⚠️ | ⚠️ | ✅ |
| **Offline Ready** | ✅ | ✅ | ❌ | ✅ |

This makes textual jmux ideal for:
- 🔒 **Secure environments** (no web access needed)  
- 🌍 **Remote servers** (no GUI requirements)
- 📱 **Mobile development** (works on tablets/phones)
- 🚀 **Quick setup** (no complex configuration)

The Python/Textual approach gives you the best of both worlds: modern TUI experience with universal SSH compatibility!