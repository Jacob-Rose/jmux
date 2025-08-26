# Agent Guidelines

This file provides guidance to agentic coding agents operating in this repository.

## Build/Lint/Test Commands

### Testing
Run the comprehensive test suite:
```bash
bash analyze.sh test
# or directly:
cd tests && bash run_all_tests.sh
```

### Self-Analysis
Analyze code quality and complexity:
```bash
bash analyze.sh report           # Full analysis report
bash analyze.sh coverage        # Test coverage analysis  
bash analyze.sh function <name> # Analyze specific function
bash analyze.sh functions       # List all library functions
```

## Current Project State

### Architecture Overview
jmux is a tmux-based IDE with sophisticated session management and modular design:

- **`jmux.sh`**: Main script (400+ lines) - session lifecycle, config generation, cleanup
- **`lib/`**: 27 pure bash utility functions (55% test coverage) - no tmux dependencies
- **`scripts/`**: 8 tmux-dependent UI features with popup-based interfaces
- **`tests/`**: 87 assertions across comprehensive test framework
- **`analyze.sh`**: Self-analysis CLI with complexity monitoring

### Key Features Implemented
1. **Bulletproof Session Cleanup** - Handles ranger crashes, improper exits, stuck sessions
2. **Auto-switch Setting System** - Configurable nvim pane switching behavior with immediate apply
3. **Tab Toggle Navigation** - Single Tab key switches between ranger/nvim bidirectionally
4. **Persistent Terminal System** - 3-tab terminal sessions with `:` command palette
5. **Settings Menu Integration** - Theme selection, auto-switch, file preview, hidden files
6. **Fuzzy File Finder** - Cached file search with preview popups
7. **Git Integration** - Lazygit popup, interactive log viewer with commit breakdowns

### Recent Major Fixes
- **Session persistence across reconnections** - Terminal command palette works reliably
- **Config reload system** - Settings apply immediately via Ctrl+R in ranger
- **First-time nvim spawn behavior** - Respects auto-switch setting on initial file opening
- **Bash history pollution prevention** - Removed problematic send-keys commands
- **Key binding lifecycle management** - Proper cleanup of global `:` bindings

## Code Style Guidelines

### Architecture Principles
- **Session isolation**: Terminal sessions manage their own key bindings and cleanup
- **Config generation**: Dynamic ranger/nvim configs based on user settings
- **Popup interfaces**: All complex UIs use tmux display-popup for non-blocking interaction
- **Graceful degradation**: Features work with fallback keybindings (F1/F2, Ctrl+B combinations)

### Language Standards
- **Bash scripts**: Must use `#!/bin/bash` shebang (not `#!/bin/sh`)
- **POSIX compatibility**: Use `.` instead of `source` for better portability
- **Error handling**: Include proper cleanup traps and error checking
- **Testing**: Extract complex logic into `lib/` functions with corresponding tests
- **No comments in generated code** unless explicitly requested

### Session Management Patterns
1. **Trap-based cleanup** - Always use `trap cleanup_function EXIT INT TERM HUP QUIT`
2. **Temp file naming** - Use `$$.sh` suffix for unique process-based naming
3. **Key binding lifecycle** - Bind on creation, unbind on cleanup
4. **Config regeneration** - Check for existing sessions before creating new bindings

### New Function Development
1. **Pure functions**: Add to appropriate `lib/*.sh` module
2. **Add tests**: Create corresponding test functions in `tests/test_*.sh`
3. **Run analysis**: Use `bash analyze.sh function <name>` to check complexity
4. **Target coverage**: Maintain >50% test coverage across library functions

### UI Feature Development
1. **Use tmux display-popup** for all interactive interfaces
2. **Implement proper cleanup** - temp files, key bindings, session state
3. **Handle reconnection scenarios** - recreate necessary state on session reattach
4. **Avoid bash history pollution** - use script execution over send-keys

## Git Workflow

- **iter** branch - Development/unstable features
- **dev** branch - Stable but not shippable  
- **main** branch - Production ready

## Dependencies

Required:
- tmux, ranger, nvim, lazygit, fzf

Optional (improves experience):
- git-delta for enhanced diff output in git log viewer:
  ```bash
  brew install git-delta # macOS
  sudo apt install git-delta # Debian/Ubuntu
  ```

## Testing Framework

The project includes a comprehensive testing system:
- **Test Framework**: `tests/test_framework.sh` - Simple assertion-based testing
- **Coverage**: Currently 55% function coverage (15/27 functions tested)
- **Modules**: Each `lib/*.sh` file has corresponding `tests/test_*.sh` file
- **Self-Analysis**: Automated complexity analysis and security issue detection

### Adding New Tests
```bash
# Add test function to appropriate test_*.sh file:
test_my_function() {
    local result="$(my_function "input")"
    assert_equals "expected" "$result" "my_function returns expected value"
}

# Run tests to verify:
bash analyze.sh test
```

## Quality Standards

- **Complexity**: Functions with complexity >20 should be refactored
- **Security**: Avoid command injection risks (check with `bash analyze.sh function <name>`)
- **Dependencies**: Library functions must have zero tmux dependencies
- **Error Handling**: Include proper error handling for file operations
- **Session Management**: Always implement proper cleanup and reconnection handling

## Common Patterns & Best Practices

### Settings System
- Save to `~/.config/jmux/settings` in KEY="value" format
- Use `save_setting()` and `load_setting()` functions from `lib/config_utils.sh`
- Apply immediately by regenerating config files and reloading (Ctrl+R)

### Popup Creation
```bash
# Standard popup pattern
tmux display-popup -w 60% -h 70% -E "/path/to/script.sh"

# With session isolation
tmux bind-key -T root key "display-popup -w 50% -h 60% -E '$SCRIPT_PATH'"
```

### Command Palette Implementation
```bash
# Create palette script with proper case handling
case "$cmd" in
    "q"|"Q") tmux detach-client ;;
    "1") tmux select-window -t session:0 ;;
    *) echo "Unknown command" ;;
esac
```

### Troubleshooting Common Issues
- **Key bindings not working**: Check if global bindings conflict, use session-specific bindings
- **Scripts not found**: Ensure proper temp file cleanup and recreation on reconnection
- **Settings not applying**: Verify config regeneration and reload mechanisms
- **History pollution**: Use script execution instead of send-keys commands

