#!/bin/bash

# Test suite for config_utils.sh

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
load_lib "config_utils.sh"

# Test functions
test_save_and_get_config_setting() {
    setup_test_env
    
    local config_file="$TEST_DIR/test.conf"
    
    # Test saving a setting
    save_config_setting "$config_file" "TEST_KEY" "test_value"
    assert_true "[ -f '$config_file' ]" "save_config_setting creates config file"
    
    # Test getting the saved setting
    local result="$(get_config_value "$config_file" "TEST_KEY" "default")"
    assert_equals "test_value" "$result" "get_config_value returns saved value"
    
    # Test getting non-existent key with default
    result="$(get_config_value "$config_file" "NONEXISTENT" "default_val")"
    assert_equals "default_val" "$result" "get_config_value returns default for non-existent key"
    
    teardown_test_env
}

test_validate_config_format() {
    setup_test_env
    
    local good_config="$TEST_DIR/good.conf"
    local bad_config="$TEST_DIR/bad.conf"
    
    # Create valid config
    cat > "$good_config" << EOF
# This is a comment
KEY1="value1"
KEY2="value2"
ANOTHER_KEY="another value"
EOF
    
    # Create invalid config
    cat > "$bad_config" << EOF
KEY1="value1"
invalid line without equals
KEY2="value2"  
EOF
    
    assert_true "validate_config_format '$good_config'" "validate_config_format accepts valid config"
    assert_false "validate_config_format '$bad_config'" "validate_config_format rejects invalid config"
    
    teardown_test_env
}

test_merge_configs() {
    setup_test_env
    
    local base_config="$TEST_DIR/base.conf"
    local override_config="$TEST_DIR/override.conf"
    local merged_config="$TEST_DIR/merged.conf"
    
    # Create base config
    cat > "$base_config" << EOF
BASE_KEY1="base_value1"
BASE_KEY2="base_value2"
COMMON_KEY="base_common"
EOF
    
    # Create override config
    cat > "$override_config" << EOF
OVERRIDE_KEY1="override_value1"
COMMON_KEY="override_common"
EOF
    
    # Merge configs
    merge_configs "$base_config" "$override_config" "$merged_config"
    
    # Test merged results
    local result="$(get_config_value "$merged_config" "BASE_KEY1" "")"
    assert_equals "base_value1" "$result" "merge_configs preserves base keys"
    
    result="$(get_config_value "$merged_config" "OVERRIDE_KEY1" "")"
    assert_equals "override_value1" "$result" "merge_configs adds override keys"
    
    result="$(get_config_value "$merged_config" "COMMON_KEY" "")"
    assert_equals "override_common" "$result" "merge_configs overrides common keys"
    
    teardown_test_env
}

test_load_config() {
    setup_test_env
    
    local config_file="$TEST_DIR/load_test.conf"
    
    # Create config file
    cat > "$config_file" << EOF
LOAD_TEST_VAR1="loaded_value1"
LOAD_TEST_VAR2="loaded_value2"
EOF
    
    # Load config
    load_config "$config_file"
    
    # Test loaded variables
    assert_equals "loaded_value1" "$LOAD_TEST_VAR1" "load_config sets environment variable 1"
    assert_equals "loaded_value2" "$LOAD_TEST_VAR2" "load_config sets environment variable 2"
    
    teardown_test_env
}

# Run the test suite
run_test_suite "Config Utils Tests" \
    test_save_and_get_config_setting \
    test_validate_config_format \
    test_merge_configs \
    test_load_config

print_test_summary