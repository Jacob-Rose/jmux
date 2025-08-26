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

## Code Style Guidelines

### Architecture
- **`jmux.sh`**: Main script, uses bash with proper session lifecycle management
- **`lib/`**: Pure bash utility functions (no tmux dependencies) - use these for reusable logic
- **`tests/`**: Comprehensive test framework with 87 assertions covering core functionality
- **`scripts/`**: tmux-dependent helper scripts for UI features
- **`analyze.sh`**: Self-analysis CLI tool for code quality monitoring

### Language Standards
- **Bash scripts**: Must use `#!/bin/bash` shebang (not `#!/bin/sh`)
- **POSIX compatibility**: Use `.` instead of `source` for better portability
- **Error handling**: Include proper cleanup traps and error checking
- **Testing**: Extract complex logic into `lib/` functions with corresponding tests

### New Function Development
1. **Pure functions**: Add to appropriate `lib/*.sh` module
2. **Add tests**: Create corresponding test functions in `tests/test_*.sh`
3. **Run analysis**: Use `bash analyze.sh function <name>` to check complexity
4. **Target coverage**: Maintain >50% test coverage across library functions

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

