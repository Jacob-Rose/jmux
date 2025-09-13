#!/bin/bash

# Integration test framework for jmux application testing
# Tests full jmux functionality including tmux sessions and file operations

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "/home/jakee/jmux/tests/test_framework.sh"

# Integration test configuration
JMUX_TEST_TIMEOUT=30
JMUX_TEST_DIR="/tmp/jmux_integration_test_$$"
JMUX_SESSION_PREFIX="jmux-"

# Load logging utilities for log analysis
if [ -f "/home/jakee/jmux/scripts/jmux_logging_utilities.sh" ]; then
    . "/home/jakee/jmux/scripts/jmux_logging_utilities.sh"
fi

# Integration test utilities
setup_integration_env() {
    # Create test directory
    mkdir -p "$JMUX_TEST_DIR"
    cd "$JMUX_TEST_DIR"

    # Create test files
    echo "This is a test README file for jmux integration testing." > README.md
    echo "Test content for integration testing." > test.txt

    # Clear any existing logs
    clear_log "jmux" 2>/dev/null || true
    clear_log "enter_helper" 2>/dev/null || true
    clear_log "enter_helper_noswitch" 2>/dev/null || true

    # Clean up old status files and create test marker
    rm -f /tmp/jmux_status_* 2>/dev/null || true
    touch /tmp/jmux_test_mode

    export JMUX_TEST_DIR
    export JMUX_SESSION_PREFIX
}

teardown_integration_env() {
    # Kill any test sessions
    tmux list-sessions 2>/dev/null | grep "$JMUX_SESSION_PREFIX" | cut -d: -f1 | xargs -r tmux kill-session -t 2>/dev/null || true

    # Clean up test directory
    if [ -n "$JMUX_TEST_DIR" ] && [ -d "$JMUX_TEST_DIR" ]; then
        rm -rf "$JMUX_TEST_DIR"
    fi

    # Clean up logs, status files, and test marker
    rm -rf /tmp/jmux* 2>/dev/null || true
    rm -f /tmp/jmux_status_* 2>/dev/null || true
    rm -f /tmp/jmux_test_mode 2>/dev/null || true
}

run_jmux_background() {
    local work_dir="${1:-$JMUX_TEST_DIR}"
    
    echo "Starting jmux in background (dir: $work_dir)"
    
    # Create test marker file for automatic detection
    touch /tmp/jmux_test_mode
    
    # Start jmux (will auto-detect test mode)
    "$SCRIPT_DIR/../jmux.sh" "$work_dir" >/dev/null 2>&1 &
    JMUX_PID=$!
    
    echo "Jmux started with PID: $JMUX_PID"
    
    # Verify the process is running
    if kill -0 "$JMUX_PID" 2>/dev/null; then
        echo "✓ Jmux process is running"
    else
        echo "✗ Jmux process failed to start"
        return 1
    fi
    
    # Store the expected status file path for this process
    JMUX_STATUS_FILE="/tmp/jmux_status_$JMUX_PID"
    export JMUX_STATUS_FILE
    export JMUX_PID
    return 0
}

wait_for_status() {
    local expected_status="$1"
    local max_wait="${2:-15}"
    
    echo "Waiting for status: $expected_status (max ${max_wait}s)"
    
    # Check if we have a specific status file for this process
    if [ -n "$JMUX_STATUS_FILE" ] && [ -f "$JMUX_STATUS_FILE" ]; then
        echo "Checking specific status file: $JMUX_STATUS_FILE"
        for i in $(seq 1 "$max_wait"); do
            echo "Status check $i: Checking $JMUX_STATUS_FILE"
            if [ -f "$JMUX_STATUS_FILE" ]; then
                current_status=$(cat "$JMUX_STATUS_FILE" 2>/dev/null)
                echo "  Current status: '$current_status'"
                if [ "$current_status" = "$expected_status" ]; then
                    echo "✓ Status '$expected_status' reached"
                    return 0
                fi
            fi
            sleep 1
        done
    else
        # Fallback to searching all status files
        echo "No specific status file, searching all status files..."
        for i in $(seq 1 "$max_wait"); do
            echo "Status check $i: Looking for status files..."
            # Use find command to be more reliable
            status_files=$(find /tmp -name "jmux_status_*" -type f 2>/dev/null)
            status_files_found=0
            for status_file in $status_files; do
                if [ -f "$status_file" ]; then
                    status_files_found=$((status_files_found + 1))
                    current_status=$(cat "$status_file" 2>/dev/null)
                    echo "  Found file $status_file: '$current_status'"
                    if [ "$current_status" = "$expected_status" ]; then
                        echo "✓ Status '$expected_status' reached"
                        export JMUX_STATUS_FILE="$status_file"
                        return 0
                    fi
                fi
            done
            if [ $status_files_found -eq 0 ]; then
                echo "  No status files found yet"
            fi
            sleep 1
        done
    fi
    
    echo "✗ Status '$expected_status' not reached after ${max_wait}s"
    # Show all status files and their contents
    echo "Status files found:"
    for status_file in /tmp/jmux_status_*; do
        if [ -f "$status_file" ]; then
            echo "  $status_file: $(cat "$status_file" 2>/dev/null)"
        fi
    done
    return 1
}

wait_for_session() {
    # First wait for jmux to be ready for testing
    if ! wait_for_status "ready_for_testing" 10; then
        return 1
    fi

    # Then verify the tmux session exists
    local session_name
    session_name=$(get_jmux_session_name)

    if [ -n "$session_name" ] && tmux has-session -t "$session_name" 2>/dev/null; then
        echo "✓ Jmux session verified: $session_name"
        return 0
    else
        echo "✗ Jmux session not found despite ready status"
        return 1
    fi
}

get_jmux_session_name() {
    tmux list-sessions 2>/dev/null | grep "^jmux-" | head -1 | cut -d: -f1
}

simulate_file_open() {
    local file_path="$1"
    local session_name="$2"
    
    if [ -z "$session_name" ]; then
        session_name="$(get_jmux_session_name)"
    fi
    
    if [ -z "$session_name" ]; then
        echo "No jmux session found"
        return 1
    fi
    
    echo "Simulating file open: $file_path in session: $session_name"
    
    # Use external command interface for more realistic simulation
    local external_cmd="$SCRIPT_DIR/../scripts/external_command.sh"
    if [ -f "$external_cmd" ]; then
        # Set the session explicitly for the external command
        export JMUX_TEST_SESSION="$session_name"
        # First navigate ranger to the file
        "$external_cmd" open-file-ranger "$file_path"
        
        # Wait a moment for navigation
        sleep 1
        
        # Send Enter key to open the file (this triggers the enter helper)
        "$external_cmd" ranger "Enter"
        
        # Unset the session variable
        unset JMUX_TEST_SESSION
        
        return $?
    else
        # Fallback to direct enter helper call
        local enter_helper="$SCRIPT_DIR/../scripts/enter_helper.sh"
        if [ -f "$enter_helper" ]; then
            "$enter_helper" "$file_path" "$JMUX_TEST_DIR"
            return $?
        else
            echo "Neither external command nor enter helper found"
            return 1
        fi
    fi
}

verify_logs_no_errors() {
    local component="$1"
    local error_patterns="${2:-size missing}"

    echo "Checking logs for errors in component: $component"

    # Get log content
    local log_content=""
    if [ -f "../tmp/${component}.log" ]; then
        log_content="$(cat "../tmp/${component}.log")"
    elif [ -f "/tmp/jmux/${component}.log" ]; then
        log_content="$(cat "/tmp/jmux/${component}.log")"
    fi

    if [ -z "$log_content" ]; then
        echo "No log content found for $component"
        return 1
    fi

    # Check for error patterns
    local has_errors=false
    for pattern in $error_patterns; do
        if echo "$log_content" | grep -q "$pattern"; then
            echo "✗ Found error pattern: $pattern"
            has_errors=true
        fi
    done

    if [ "$has_errors" = false ]; then
        echo "✓ No error patterns found in $component logs"
        return 0
    else
        echo "✗ Errors found in $component logs"
        return 1
    fi
}

verify_file_opened() {
    local file_path="$1"
    local session_name="$2"

    if [ -z "$session_name" ]; then
        session_name="$(get_jmux_session_name)"
    fi

    echo "Verifying file opened: $file_path in session: $session_name"

    # Check if session has 2 panes (ranger + nvim)
    local pane_count
    pane_count=$(tmux list-panes -t "$session_name" 2>/dev/null | wc -l)

    if [ "$pane_count" -eq 2 ]; then
        echo "✓ Session has 2 panes (ranger + nvim)"
        return 0
    else
        echo "✗ Session has $pane_count panes, expected 2"
        return 1
    fi
}

cleanup_session() {
    local session_name="$1"

    if [ -z "$session_name" ]; then
        session_name="$(get_jmux_session_name)"
    fi

    if [ -n "$session_name" ]; then
        echo "Cleaning up session: $session_name"
        tmux kill-session -t "$session_name" 2>/dev/null || true
    fi

    if [ -n "$JMUX_PID" ]; then
        kill "$JMUX_PID" 2>/dev/null || true
    fi
}

# Integration test runner
run_integration_test() {
    local test_name="$1"
    local test_function="$2"

    echo -e "\n${YELLOW}Running integration test: $test_name${NC}"
    echo "----------------------------------------"

    # Setup
    setup_integration_env

    # Run test
    local result=1
    if type "$test_function" >/dev/null 2>&1; then
        if "$test_function"; then
            result=0
        fi
    else
        echo -e "${RED}✗${NC} Test function '$test_function' not found"
    fi

    # Cleanup
    teardown_integration_env

    return $result
}