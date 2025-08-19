# Agent Guidelines

This file provides guidance to agentic coding agents operating in this repository.

## Build/Lint/Test Commands

No build/lint/test commands found.

## Code Style Guidelines

Key Components:
- `jmux.sh`: Main script, uses bash.
- `install.sh`: Installation script, uses bash.
- Ranger config: Uses ranger.
- Nvim config: Uses lua.

Git Workflow:
- Start on "iter" branch (unstable).
- Squash and merge to "dev" (stable but not shippable).
- Merge to main (shippable).

## Dependencies

- To improve the git diff output in the git log viewer, install the `delta` tool:
  ```bash
  brew install git-delta # macOS
  sudo apt install git-delta # Debian/Ubuntu
  ```

