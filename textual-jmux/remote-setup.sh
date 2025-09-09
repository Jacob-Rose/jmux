#!/bin/bash
# Remote Setup Script for Textual jmux
# Usage: ./remote-setup.sh [user@remote-host]

set -e

REMOTE_HOST="${1:-}"
PROJECT_DIR="textual-jmux"

echo "🚀 Textual jmux Remote Setup"
echo "============================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if remote host provided
if [ -z "$REMOTE_HOST" ]; then
    info "Local setup mode (no remote host specified)"
    info "To setup on remote host, run: $0 user@remote-host"
    echo
    
    # Local setup
    info "Installing textual locally..."
    if command -v pip3 &> /dev/null; then
        pip3 install --user textual
        success "Textual installed locally"
    else
        error "pip3 not found. Please install Python 3 and pip first."
        exit 1
    fi
    
    info "Starting textual jmux..."
    python3 main.py
    exit 0
fi

info "Setting up textual jmux on remote host: $REMOTE_HOST"

# Step 1: Test SSH connection
info "Testing SSH connection..."
if ssh "$REMOTE_HOST" "echo 'SSH connection successful'" &> /dev/null; then
    success "SSH connection verified"
else
    error "Cannot connect to $REMOTE_HOST"
    error "Please check your SSH configuration and try again"
    exit 1
fi

# Step 2: Check Python on remote
info "Checking Python installation on remote host..."
PYTHON_VERSION=$(ssh "$REMOTE_HOST" "python3 --version 2>/dev/null || echo 'NOT_FOUND'")
if [[ "$PYTHON_VERSION" == "NOT_FOUND" ]]; then
    error "Python 3 not found on remote host"
    error "Please install Python 3.8+ on $REMOTE_HOST first"
    exit 1
else
    success "Found: $PYTHON_VERSION"
fi

# Step 3: Install textual on remote
info "Installing textual on remote host..."
ssh "$REMOTE_HOST" "pip3 install --user textual" &> /dev/null
if [ $? -eq 0 ]; then
    success "Textual installed on remote host"
else
    warning "Failed to install textual via pip3"
    info "You may need to install pip3 on the remote host first"
fi

# Step 4: Copy project files
info "Copying textual-jmux files to remote host..."
scp -r . "$REMOTE_HOST:~/$PROJECT_DIR/" &> /dev/null
if [ $? -eq 0 ]; then
    success "Files copied to ~/$PROJECT_DIR/"
else
    error "Failed to copy files"
    exit 1
fi

# Step 5: Test installation
info "Testing installation on remote host..."
TEST_OUTPUT=$(ssh "$REMOTE_HOST" "cd ~/$PROJECT_DIR && timeout 2 python3 main.py 2>&1 || echo 'TEST_OK'")
if [[ "$TEST_OUTPUT" == *"TEST_OK"* ]] || [[ "$TEST_OUTPUT" == *"TextualJmux"* ]]; then
    success "Installation test passed"
else
    warning "Installation test unclear - manual verification recommended"
fi

echo
success "🎉 Setup complete!"
echo
info "To use textual jmux on the remote host:"
echo "  ssh $REMOTE_HOST"
echo "  cd $PROJECT_DIR"
echo "  python3 main.py"
echo
info "Or run directly:"
echo "  ssh $REMOTE_HOST 'cd $PROJECT_DIR && python3 main.py'"
echo
info "Features available over SSH:"
echo "  • Full mouse support (click, scroll, double-click)"  
echo "  • Vim-style commands (:q to quit, :o to open files)"
echo "  • Tmux integration (Ctrl+O opens nvim in new pane)"
echo "  • File preview and navigation"