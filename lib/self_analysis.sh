#!/bin/bash

# Self-analysis functions for jmux library code

# Source all library utilities for analysis
if [ -z "$LIB_DIR" ]; then
    LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "$LIB_DIR/path_utils.sh"
source "$LIB_DIR/config_utils.sh"
source "$LIB_DIR/theme_utils.sh"
source "$LIB_DIR/input_utils.sh"

# Analyze function complexity by counting lines and branches
# Usage: analyze_function_complexity "function_name"
analyze_function_complexity() {
    local func_name="$1"
    local lib_files="$(find "$LIB_DIR" -name "*.sh" -not -name "self_analysis.sh")"
    
    echo "=== Function Complexity Analysis for: $func_name ==="
    
    for lib_file in $lib_files; do
        if grep -q "^$func_name()" "$lib_file"; then
            local lines=$(sed -n "/^$func_name()/,/^}/p" "$lib_file" | wc -l)
            local branches=$(sed -n "/^$func_name()/,/^}/p" "$lib_file" | grep -c -E "(if|case|while|for)")
            local returns=$(sed -n "/^$func_name()/,/^}/p" "$lib_file" | grep -c "return")
            
            echo "File: $(basename "$lib_file")"
            echo "  Lines: $lines"
            echo "  Branches: $branches"
            echo "  Return statements: $returns"
            echo "  Complexity score: $((lines + branches * 2))"
            echo ""
        fi
    done
}

# List all functions in library
# Usage: list_library_functions
list_library_functions() {
    local lib_files="$(find "$LIB_DIR" -name "*.sh" -not -name "self_analysis.sh")"
    
    echo "=== Library Functions ==="
    
    for lib_file in $lib_files; do
        echo "$(basename "$lib_file"):"
        grep "^[a-zA-Z_][a-zA-Z0-9_]*(" "$lib_file" | sed 's/() {//g' | sed 's/^/  - /'
        echo ""
    done
}

# Analyze test coverage
# Usage: analyze_test_coverage
analyze_test_coverage() {
    local test_dir="$LIB_DIR/../tests"
    
    echo "=== Test Coverage Analysis ==="
    
    if [ ! -d "$test_dir" ]; then
        echo "Test directory not found: $test_dir"
        return 1
    fi
    
    # Get all library functions
    local all_functions=$(find "$LIB_DIR" -name "*.sh" -not -name "self_analysis.sh" -exec grep "^[a-zA-Z_][a-zA-Z0-9_]*(" {} \; | sed 's/() {//g' | sort -u)
    
    # Get all tested functions
    local tested_functions=$(find "$test_dir" -name "test_*.sh" -exec grep -h "test_.*(" {} \; | sed 's/test_//g' | sed 's/() {//g' | sort -u)
    
    local total_functions=$(echo "$all_functions" | wc -l)
    local total_tests=$(find "$test_dir" -name "test_*.sh" -exec grep -c "assert_" {} \; | awk '{sum += $1} END {print sum}')
    
    echo "Total library functions: $total_functions"
    echo "Total test assertions: $total_tests"
    echo ""
    
    echo "Functions with tests:"
    for func in $all_functions; do
        if echo "$tested_functions" | grep -q "$func"; then
            echo "  ✓ $func"
        else
            echo "  ✗ $func (no tests)"
        fi
    done
    
    echo ""
    local covered_count=$(comm -12 <(echo "$all_functions" | sort) <(echo "$tested_functions" | sort) | wc -l)
    local coverage_percent=$((covered_count * 100 / total_functions))
    echo "Test coverage: $coverage_percent% ($covered_count/$total_functions functions)"
}

# Run self-analysis on a specific function
# Usage: self_analyze_function "get_absolute_path"
self_analyze_function() {
    local func_name="$1"
    
    if [ -z "$func_name" ]; then
        echo "Usage: self_analyze_function <function_name>"
        return 1
    fi
    
    echo "=== Self-Analysis Report for: $func_name ==="
    echo ""
    
    # Basic complexity analysis
    analyze_function_complexity "$func_name"
    
    # Check if function has tests
    local test_dir="$LIB_DIR/../tests"
    if find "$test_dir" -name "test_*.sh" -exec grep -l "$func_name" {} \; >/dev/null 2>&1; then
        echo "✓ Function has test coverage"
    else
        echo "✗ Function lacks test coverage"
    fi
    echo ""
    
    # Analyze function dependencies
    local lib_files="$(find "$LIB_DIR" -name "*.sh" -not -name "self_analysis.sh")"
    local deps=$(grep -A 20 "^$func_name()" $lib_files | grep -o '[a-zA-Z_][a-zA-Z0-9_]*(' | sed 's/(//g' | grep -v "$func_name" | sort -u)
    
    if [ -n "$deps" ]; then
        echo "Function dependencies:"
        for dep in $deps; do
            echo "  - $dep"
        done
    else
        echo "✓ Function has no internal dependencies"
    fi
    echo ""
    
    # Check for potential issues
    echo "Potential issues:"
    local issues_found=0
    
    for lib_file in $lib_files; do
        if grep -q "^$func_name()" "$lib_file"; then
            # Check for hardcoded paths
            if sed -n "/^$func_name()/,/^}/p" "$lib_file" | grep -q "/home/\|/tmp/"; then
                echo "  ⚠ Contains hardcoded paths"
                issues_found=$((issues_found + 1))
            fi
            
            # Check for missing error handling
            if sed -n "/^$func_name()/,/^}/p" "$lib_file" | grep -q "cd\|mv\|cp" && ! sed -n "/^$func_name()/,/^}/p" "$lib_file" | grep -q "2>/dev/null\||| return"; then
                echo "  ⚠ May lack error handling for file operations"
                issues_found=$((issues_found + 1))
            fi
            
            # Check for shell injection risks
            if sed -n "/^$func_name()/,/^}/p" "$lib_file" | grep -q 'eval\|\$(\|`'; then
                echo "  ⚠ Contains command substitution - check for injection risks"
                issues_found=$((issues_found + 1))
            fi
        fi
    done
    
    if [ $issues_found -eq 0 ]; then
        echo "  ✓ No obvious issues detected"
    fi
    echo ""
}

# Generate comprehensive self-analysis report
# Usage: generate_self_analysis_report
generate_self_analysis_report() {
    echo "================================="
    echo "    jmux Library Self-Analysis   "
    echo "================================="
    echo ""
    
    list_library_functions
    echo ""
    
    analyze_test_coverage
    echo ""
    
    echo "=== High-Complexity Functions ==="
    local lib_files="$(find "$LIB_DIR" -name "*.sh" -not -name "self_analysis.sh")"
    local all_functions=$(grep "^[a-zA-Z_][a-zA-Z0-9_]*(" $lib_files | sed 's/.*://g' | sed 's/() {//g' | sort -u)
    
    for func in $all_functions; do
        for lib_file in $lib_files; do
            if grep -q "^$func()" "$lib_file"; then
                local lines=$(sed -n "/^$func()/,/^}/p" "$lib_file" | wc -l)
                local branches=$(sed -n "/^$func()/,/^}/p" "$lib_file" | grep -c -E "(if|case|while|for)")
                local complexity=$((lines + branches * 2))
                
                if [ $complexity -gt 20 ]; then
                    echo "  $func (complexity: $complexity)"
                fi
            fi
        done
    done
    echo ""
    
    echo "=== Recommendations ==="
    echo "1. Focus on testing functions without coverage"
    echo "2. Consider refactoring high-complexity functions"
    echo "3. Add error handling where missing"
    echo "4. Review functions with potential security issues"
    echo ""
}