#!/bin/bash

# File opening integration tests for jmux
# Tests the core functionality of opening files through ranger

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_integration.sh"

# Test: Basic jmux startup and session creation
test_jmux_startup() {
    echo "Testing basic jmux startup"

    # Start jmux in background
    run_jmux_background "$JMUX_TEST_DIR"

    # Wait a bit for startup
    sleep 3

    # Check if jmux process is still running
    if ! kill -0 "$JMUX_PID" 2>/dev/null; then
        echo "Jmux process died"
        return 1
    fi

    # Check if tmux session was created
    local session_count
    session_count=$(tmux list-sessions 2>/dev/null | wc -l)

    if [ "$session_count" -gt 0 ]; then
        echo "✓ Jmux created tmux session"
        cleanup_session
        return 0
    else
        echo "✗ No tmux session found"
        cleanup_session
        return 1
    fi
}

# Test: Open README.md file (simplified)
test_open_readme_md() {
    local readme_path="$JMUX_TEST_DIR/README.md"

    echo "Testing README.md file opening"

    # Start jmux in background
    run_jmux_background "$JMUX_TEST_DIR"

    # Wait for startup
    sleep 3

    # Get session name
    local session_name
    session_name=$(get_jmux_session_name)

    if [ -z "$session_name" ]; then
        echo "Could not get session name"
        cleanup_session
        return 1
    fi

    echo "Session name: $session_name"

    # Simulate opening README.md
    if ! simulate_file_open "$readme_path" "$session_name"; then
        echo "File opening simulation failed"
        cleanup_session
        return 1
    fi

    # Wait for operation to complete
    sleep 2

    # Check if session still has 2 panes (indicating file was opened)
    local pane_count
    pane_count=$(tmux list-panes -t "$session_name" 2>/dev/null | wc -l)

    if [ "$pane_count" -eq 2 ]; then
        echo "✓ README.md opened successfully (2 panes)"
        cleanup_session "$session_name"
        return 0
    else
        echo "✗ File opening failed (pane count: $pane_count)"
        cleanup_session "$session_name"
        return 1
    fi
}

# Test: Verify no size missing errors
test_no_size_missing_errors() {
    echo "Testing for absence of 'size missing' errors"
    
    # Start jmux
    run_jmux_background "$JMUX_TEST_DIR"
    
    if ! wait_for_session 5; then
        cleanup_session
        return 1
    fi
    
    local session_name
    session_name=$(get_jmux_session_name)
    
    # Just wait a bit to let the session stabilize
    sleep 2
    
    # Verify no size missing errors in logs
    if verify_logs_no_errors "jmux" "size missing"; then
        echo "✓ No 'size missing' errors found"
        cleanup_session "$session_name"
        return 0
    else
        echo "✗ 'size missing' errors found"
        cleanup_session "$session_name"
        return 1
    fi
}

# Test: Session cleanup works properly
test_session_cleanup() {
    echo "Testing session cleanup"

    # Start jmux
    run_jmux_background "$JMUX_TEST_DIR"

    if ! wait_for_session 5; then
        return 1
    fi

    local session_name
    session_name=$(get_jmux_session_name)

    if [ -z "$session_name" ]; then
        return 1
    fi

    # Verify session exists
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "Session does not exist after creation"
        return 1
    fi

    # Cleanup
    cleanup_session "$session_name"

    # Wait a moment
    sleep 1

    # Verify session is gone
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "Session still exists after cleanup"
        return 1
    else
        echo "✓ Session cleaned up successfully"
        return 0
    fi
}

# Run tests if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Running file opening integration tests..."

    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0

    # Run individual tests
    test_functions=(
        "test_jmux_startup"
        "test_open_readme_md"
        "test_no_size_missing_errors"
        "test_session_cleanup"
    )

    for test_func in "${test_functions[@]}"; do
        if run_integration_test "$test_func" "$test_func"; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    done

    # Summary
    echo -e "\n${BLUE}File Opening Integration Test Summary:${NC}"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All file opening tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some file opening tests failed.${NC}"
        exit 1
    fi
fi