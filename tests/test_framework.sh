#!/bin/bash

# Simple test framework for jmux library functions

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result reporting
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Condition failed: $condition"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if ! eval "$condition"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Condition should have failed: $condition"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test suite management
run_test_suite() {
    local suite_name="$1"
    shift
    local test_functions=("$@")
    
    echo -e "${YELLOW}Running test suite: $suite_name${NC}"
    echo "----------------------------------------"
    
    for test_func in "${test_functions[@]}"; do
        if type "$test_func" >/dev/null 2>&1; then
            "$test_func"
        else
            echo -e "${RED}✗${NC} Test function '$test_func' not found"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done
    
    echo "----------------------------------------"
}

# Final test summary
print_test_summary() {
    echo ""
    echo "Test Summary:"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Test isolation helpers
setup_test_env() {
    # Create temporary directory for test files
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    
    # Save original directory
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR
}

teardown_test_env() {
    # Return to original directory
    cd "$ORIGINAL_DIR"
    
    # Clean up test files
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Load library functions for testing
load_lib() {
    local lib_file="$1"
    local lib_path="./lib/$lib_file"
    
    if [ -f "$lib_path" ]; then
        source "$lib_path"
    elif [ -f "../lib/$lib_file" ]; then
        source "../lib/$lib_file"
    else
        echo "Error: Library file '$lib_file' not found"
        exit 1
    fi
}