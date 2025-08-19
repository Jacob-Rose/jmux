# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

**jmux** is a tmux-based IDE that combines ranger (file manager) and nvim (text editor) in a 40%/60% split-pane interface with integrated git workflow via lazygit popups.

## Key Components

### jmux.sh
Main executable that creates the development environment:
- Generates persistent config files in `~/.config/jmux/`
- Launches tmux session named "ide" with split panes (40% ranger, 60% nvim)  
- Works from any directory with optional path argument: `jmux [directory]`
- Configures custom keybindings and tmux popup integration

### install.sh
System installation script:
- Installs jmux as global command to `/usr/local/bin/jmux`
- Validates dependencies: tmux, ranger, nvim, lazygit
- Creates uninstall script at `~/.config/jmux/uninstall.sh`

## Usage

After installation:
```bash
jmux                    # Start IDE in current directory
jmux /path/to/project   # Start IDE in specific directory
```

## Key Features & Keybindings

### File Management
- **Enter** in ranger: Opens files in nvim using `readlink -f` for absolute paths
- **Right arrow**: Only enters directories, never opens files
- **Tab/Shift+Tab**: Switch between ranger and nvim panes

### Git Integration  
- **`;g`** in ranger: Opens lazygit in 90% screen popup overlay
- **`q`** in lazygit: Closes popup and returns to IDE

### Session Management
- **`:q`** in nvim: Exits entire IDE session
- Unified quit mechanism: Either application exiting terminates the whole session
- Disabled ranger's default `q` quit key to prevent accidental exits

## Architecture Notes

- Uses `tmux display-popup` for lazygit overlay with proper `%%` escaping
- File opening via `tmux send-keys` with absolute path resolution
- XDG-compliant config directory structure
- Self-contained with no external dependencies beyond core tools


## Git Workflow
- The expected development workflow with git will start on the "iter" branch, which is made to be unstable, quick, and dirty. 
- "iter" branch should then be squashed and merged into the "dev" branch, with a good commit message explaining all squashed changes in a concise manner. We merge to "dev" once some stability established, but still not shippable. 
- Merging to main from the dev branch when we are ready for a new user to install off that branch.
