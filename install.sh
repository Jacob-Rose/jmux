#!/bin/bash

# jmux installer
# Installs jmux as a system command

set -e

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jmux"
COMMAND_NAME="jmux"

echo "Installing jmux..."

echo "Checking dependencies..."

# Check tmux
echo "Testing tmux..."
if tmux -V; then
    echo "tmux is working"
else
    echo "Error: tmux is required but not working."
    echo "tmux exit code: $?"
    exit 1
fi

# Check ranger
echo "Testing ranger..."
if ranger --version; then
    echo "ranger is working"
else
    echo "Error: ranger is required but not working."
    echo "ranger exit code: $?"
    exit 1
fi

# Check nvim
echo "Testing nvim..."
if nvim --version; then
    echo "nvim is working"
else
    echo "Error: nvim is required but not working."
    echo "nvim exit code: $?"
    exit 1
fi

# Check lazygit
echo "Testing lazygit..."
if lazygit --version; then
    echo "lazygit is working"
else
    echo "Error: lazygit is required but not working."
    echo "lazygit exit code: $?"
    exit 1
fi

# Check fzf
echo "Testing fzf..."
if fzf --version; then
    echo "fzf is working"
else
    echo "Error: fzf is required but not working."
    echo "fzf exit code: $?"
    exit 1
fi

# Create config directory
echo "Creating config directory at $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR"

# Install the main script
echo "Installing jmux to $INSTALL_DIR/$COMMAND_NAME..."
sudo cp jmux.sh "$INSTALL_DIR/$COMMAND_NAME"
sudo chmod +x "$INSTALL_DIR/$COMMAND_NAME"

# Create uninstall script
echo "Creating uninstall script..."
cat > "$CONFIG_DIR/uninstall.sh" <<EOF
#!/bin/bash
echo "Uninstalling jmux..."
sudo rm -f "$INSTALL_DIR/$COMMAND_NAME"
rm -rf "$CONFIG_DIR"
echo "jmux uninstalled successfully."
EOF
chmod +x "$CONFIG_DIR/uninstall.sh"

echo ""
echo "jmux installed successfully!"
echo ""
echo "Usage:"
echo "  $COMMAND_NAME         # Start IDE in current directory"
echo ""
echo "To uninstall:"
echo "  $CONFIG_DIR/uninstall.sh"
echo ""
echo "Config directory: $CONFIG_DIR"