#!/bin/bash

# Test suite for theme_utils.sh

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
load_lib "theme_utils.sh"

# Test functions
test_get_themes() {
    local nvim_themes="$(get_nvim_themes)"
    assert_true "echo '$nvim_themes' | grep -q 'default'" "get_nvim_themes includes default theme"
    assert_true "echo '$nvim_themes' | grep -q 'desert'" "get_nvim_themes includes desert theme"
    
    local ranger_themes="$(get_ranger_themes)"
    assert_true "echo '$ranger_themes' | grep -q 'default'" "get_ranger_themes includes default theme"
    assert_true "echo '$ranger_themes' | grep -q 'jungle'" "get_ranger_themes includes jungle theme"
}

test_validate_themes() {
    assert_true "is_valid_nvim_theme 'default'" "is_valid_nvim_theme accepts default"
    assert_true "is_valid_nvim_theme 'desert'" "is_valid_nvim_theme accepts desert"
    assert_false "is_valid_nvim_theme 'nonexistent'" "is_valid_nvim_theme rejects nonexistent theme"
    
    assert_true "is_valid_ranger_theme 'default'" "is_valid_ranger_theme accepts default"
    assert_true "is_valid_ranger_theme 'jungle'" "is_valid_ranger_theme accepts jungle"
    assert_false "is_valid_ranger_theme 'nonexistent'" "is_valid_ranger_theme rejects nonexistent theme"
}

test_theme_by_index() {
    local theme="$(get_nvim_theme_by_index 1)"
    assert_equals "default" "$theme" "get_nvim_theme_by_index returns first theme"
    
    theme="$(get_nvim_theme_by_index 2)"
    assert_equals "desert" "$theme" "get_nvim_theme_by_index returns second theme"
    
    # Test invalid index
    theme="$(get_nvim_theme_by_index 0)"
    assert_equals "" "$theme" "get_nvim_theme_by_index returns empty for invalid index"
}

test_theme_index_by_name() {
    local index="$(get_nvim_theme_index 'default')"
    assert_equals "1" "$index" "get_nvim_theme_index returns 1 for default"
    
    index="$(get_nvim_theme_index 'desert')"
    assert_equals "2" "$index" "get_nvim_theme_index returns 2 for desert"
    
    # Test nonexistent theme (should return empty and exit code 1)
    index="$(get_nvim_theme_index 'nonexistent' 2>/dev/null)"
    assert_equals "" "$index" "get_nvim_theme_index returns empty for nonexistent theme"
}

test_count_themes() {
    local nvim_count="$(count_nvim_themes)"
    assert_true "[ '$nvim_count' -gt 0 ]" "count_nvim_themes returns positive number"
    
    local ranger_count="$(count_ranger_themes)"
    assert_true "[ '$ranger_count' -gt 0 ]" "count_ranger_themes returns positive number"
    
    # Verify counts match actual theme lists
    local actual_nvim_count="$(get_nvim_themes | wc -l)"
    assert_equals "$actual_nvim_count" "$nvim_count" "count_nvim_themes matches actual theme count"
    
    local actual_ranger_count="$(get_ranger_themes | wc -l)"
    assert_equals "$actual_ranger_count" "$ranger_count" "count_ranger_themes matches actual theme count"
}

# Run the test suite
run_test_suite "Theme Utils Tests" \
    test_get_themes \
    test_validate_themes \
    test_theme_by_index \
    test_theme_index_by_name \
    test_count_themes

print_test_summary