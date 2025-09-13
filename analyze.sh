#!/bin/bash

# Self-analysis CLI for jmux library
# Note: This script requires bash, not sh

# Check if running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires bash, not sh"
    echo "Please run: bash analyze.sh $*"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LIB_DIR="$SCRIPT_DIR/lib"
. "$SCRIPT_DIR/lib/self_analysis.sh"

case "${1:-help}" in
    "report")
        generate_self_analysis_report
        ;;
    "function")
        if [ -z "$2" ]; then
            echo "Usage: $0 function <function_name>"
            echo ""
            echo "Available functions:"
            list_library_functions | grep "  -" | sed 's/  - //'
            exit 1
        fi
        self_analyze_function "$2"
        ;;
    "coverage")
        analyze_test_coverage
        ;;
    "functions")
        list_library_functions
        ;;
    "test")
        cd "$SCRIPT_DIR/tests" && bash run_all_tests.sh "$@"
        ;;
    "integration-test")
        cd "$SCRIPT_DIR/tests" && bash run_all_tests.sh --integration
        ;;
    "unit-test")
        cd "$SCRIPT_DIR/tests" && bash run_all_tests.sh --unit
        ;;
    "cleanup")
        if [ -f "$SCRIPT_DIR/cleanup_jmux_sessions.sh" ]; then
            bash "$SCRIPT_DIR/cleanup_jmux_sessions.sh"
        else
            echo "Cleanup script not found"
            exit 1
        fi
        ;;
    "help"|*)
        echo "jmux Library Self-Analysis Tool"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  report          - Generate comprehensive analysis report"
        echo "  function        - Analyze specific function (requires function name)"
        echo "  coverage        - Show test coverage analysis"
        echo "  functions       - List all library functions"
        echo "  test            - Run all tests"
        echo "  integration-test- Run only integration tests"
        echo "  unit-test       - Run only unit tests"
        echo "  cleanup         - Clean up orphaned jmux sessions"
        echo "  help            - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 report"
        echo "  $0 function get_absolute_path"
        echo "  $0 coverage"
        echo "  $0 test"
        echo "  $0 cleanup"
        ;;
esac