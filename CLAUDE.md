# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository contains a tmux-based IDE setup that creates a split-pane development environment with ranger (file manager) and nvim (text editor).

## Key Components

### tmux_ide.sh
Main script that sets up the development environment:
- Creates temporary configuration directories for ranger and nvim
- Launches tmux session named "ide" with split panes (60% ranger, 40% nvim)
- Configures custom keybindings for both applications

### Configuration Files

The script generates temporary configs in:
- `ranger_temp_config/rc.conf` - Custom ranger keybindings
- `nvim_temp_config/init.lua` - Custom nvim keybindings

### Usage

Start the IDE environment:
```bash
./tmux_ide.sh
```

Exit the environment:
- Press `Ctrl+Q` in either pane
- Press `q` in ranger pane

### Key Architecture Points

- Ranger is configured to send file open commands directly to the nvim pane via tmux
- Both applications share a unified quit mechanism that cleanly tears down the tmux session
- The setup is entirely self-contained with temporary configurations