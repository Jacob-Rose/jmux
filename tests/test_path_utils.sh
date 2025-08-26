#!/bin/bash

# Test suite for path_utils.sh

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
load_lib "path_utils.sh"

# Test functions
test_get_absolute_path() {
    setup_test_env
    
    # Test with current directory
    local current_dir="$(pwd)"
    local result="$(get_absolute_path "")"
    assert_equals "$current_dir" "$result" "get_absolute_path with empty string returns current dir"
    
    # Test with relative path
    mkdir -p "$TEST_DIR/subdir"
    cd "$TEST_DIR"
    result="$(get_absolute_path "subdir")"
    assert_equals "$TEST_DIR/subdir" "$result" "get_absolute_path resolves relative directory"
    
    # Test with absolute path
    result="$(get_absolute_path "/tmp")"
    assert_equals "/tmp" "$result" "get_absolute_path returns absolute path unchanged"
    
    teardown_test_env
}

test_is_git_repo() {
    setup_test_env
    
    # Test non-git directory
    mkdir -p "$TEST_DIR/notgit"
    assert_false "is_git_repo '$TEST_DIR/notgit'" "is_git_repo returns false for non-git directory"
    
    # Test with current directory if it's a git repo
    if git rev-parse --git-dir >/dev/null 2>&1; then
        assert_true "is_git_repo '.'" "is_git_repo returns true for git directory"
    fi
    
    teardown_test_env
}

test_has_extension() {
    assert_true "has_extension 'test.txt' 'txt'" "has_extension detects txt extension"
    assert_true "has_extension 'script.sh' 'sh'" "has_extension detects sh extension"
    assert_false "has_extension 'noext' 'txt'" "has_extension returns false for file without extension"
    assert_false "has_extension 'test.txt' 'sh'" "has_extension returns false for wrong extension"
}

test_get_extension() {
    local result="$(get_extension 'test.txt')"
    assert_equals "txt" "$result" "get_extension returns correct extension"
    
    result="$(get_extension 'script.sh')"
    assert_equals "sh" "$result" "get_extension returns sh extension"
    
    result="$(get_extension 'noextension')"
    assert_equals "noextension" "$result" "get_extension returns filename for file without extension"
}

test_is_safe_path() {
    assert_true "is_safe_path '/home/user/file.txt'" "is_safe_path accepts normal path"
    assert_true "is_safe_path 'relative/path/file.txt'" "is_safe_path accepts relative path"
    
    assert_false "is_safe_path '../../../etc/passwd'" "is_safe_path rejects path traversal"
    assert_false "is_safe_path '/path/with;semicolon'" "is_safe_path rejects path with semicolon"
    assert_false "is_safe_path '/path/with|pipe'" "is_safe_path rejects path with pipe"
    assert_false "is_safe_path '/path/with\`backtick'" "is_safe_path rejects path with backtick"
}

# Run the test suite
run_test_suite "Path Utils Tests" \
    test_get_absolute_path \
    test_is_git_repo \
    test_has_extension \
    test_get_extension \
    test_is_safe_path

print_test_summary