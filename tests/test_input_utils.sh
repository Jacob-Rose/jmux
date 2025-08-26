#!/bin/bash

# Test suite for input_utils.sh

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
load_lib "input_utils.sh"

# Test functions
test_validate_numeric_input() {
    assert_true "validate_numeric_input '5' 1 10" "validate_numeric_input accepts valid number in range"
    assert_true "validate_numeric_input '1' 1 10" "validate_numeric_input accepts minimum value"
    assert_true "validate_numeric_input '10' 1 10" "validate_numeric_input accepts maximum value"
    
    assert_false "validate_numeric_input '0' 1 10" "validate_numeric_input rejects below minimum"
    assert_false "validate_numeric_input '11' 1 10" "validate_numeric_input rejects above maximum"
    assert_false "validate_numeric_input 'abc' 1 10" "validate_numeric_input rejects non-numeric"
    assert_false "validate_numeric_input '5.5' 1 10" "validate_numeric_input rejects decimal"
}

test_parse_menu_choice() {
    local result="$(parse_menu_choice '3' 5)"
    assert_equals "3" "$result" "parse_menu_choice returns valid choice"
    
    # Test invalid choice (should return empty and exit code 1)
    result="$(parse_menu_choice '0' 5 2>/dev/null)"
    assert_equals "" "$result" "parse_menu_choice returns empty for invalid choice"
    
    result="$(parse_menu_choice '6' 5 2>/dev/null)"
    assert_equals "" "$result" "parse_menu_choice returns empty for choice above max"
}

test_is_quit_command() {
    assert_true "is_quit_command 'q'" "is_quit_command accepts 'q'"
    assert_true "is_quit_command 'Q'" "is_quit_command accepts 'Q'"
    assert_true "is_quit_command 'quit'" "is_quit_command accepts 'quit'"
    assert_true "is_quit_command 'exit'" "is_quit_command accepts 'exit'"
    
    assert_false "is_quit_command 'continue'" "is_quit_command rejects non-quit command"
    assert_false "is_quit_command '5'" "is_quit_command rejects numeric input"
}

test_sanitize_input() {
    local result="$(sanitize_input 'normal input')"
    assert_equals "normal input" "$result" "sanitize_input preserves normal input"
    
    result="$(sanitize_input 'input with; dangerous stuff')"
    assert_equals "input with dangerous stuff" "$result" "sanitize_input removes semicolon"
    
    result="$(sanitize_input 'rm -rf *')"
    assert_equals "rm -rf " "$result" "sanitize_input removes dangerous characters"
}

test_validate_boolean() {
    assert_true "validate_boolean 'true'" "validate_boolean accepts 'true'"
    assert_true "validate_boolean 'false'" "validate_boolean accepts 'false'"
    assert_true "validate_boolean 'yes'" "validate_boolean accepts 'yes'"
    assert_true "validate_boolean 'no'" "validate_boolean accepts 'no'"
    assert_true "validate_boolean 'y'" "validate_boolean accepts 'y'"
    assert_true "validate_boolean 'n'" "validate_boolean accepts 'n'"
    assert_true "validate_boolean '1'" "validate_boolean accepts '1'"
    assert_true "validate_boolean '0'" "validate_boolean accepts '0'"
    
    assert_false "validate_boolean 'maybe'" "validate_boolean rejects invalid boolean"
    assert_false "validate_boolean '2'" "validate_boolean rejects invalid number"
}

test_normalize_boolean() {
    local result="$(normalize_boolean 'yes')"
    assert_equals "true" "$result" "normalize_boolean converts 'yes' to 'true'"
    
    result="$(normalize_boolean 'no')"
    assert_equals "false" "$result" "normalize_boolean converts 'no' to 'false'"
    
    result="$(normalize_boolean '1')"
    assert_equals "true" "$result" "normalize_boolean converts '1' to 'true'"
    
    result="$(normalize_boolean '0')"
    assert_equals "false" "$result" "normalize_boolean converts '0' to 'false'"
}

test_parse_key_value() {
    local result="$(parse_key_value 'KEY=value')"
    assert_equals "KEY|value" "$result" "parse_key_value parses simple key-value pair"
    
    result="$(parse_key_value 'COMPLEX_KEY=complex value with spaces')"
    assert_equals "COMPLEX_KEY|complex value with spaces" "$result" "parse_key_value handles complex values"
    
    # Test invalid input (should return empty and exit code 1)
    result="$(parse_key_value 'invalid_input' 2>/dev/null)"
    assert_equals "" "$result" "parse_key_value returns empty for invalid input"
}

# Run the test suite
run_test_suite "Input Utils Tests" \
    test_validate_numeric_input \
    test_parse_menu_choice \
    test_is_quit_command \
    test_sanitize_input \
    test_validate_boolean \
    test_normalize_boolean \
    test_parse_key_value

print_test_summary