#!/bin/bash

# Self-analysis CLI for jmux library

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LIB_DIR="$SCRIPT_DIR/lib"
source "$SCRIPT_DIR/lib/self_analysis.sh"

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
        cd "$SCRIPT_DIR/tests" && bash run_all_tests.sh
        ;;
    "help"|*)
        echo "jmux Library Self-Analysis Tool"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  report     - Generate comprehensive analysis report"
        echo "  function   - Analyze specific function (requires function name)"
        echo "  coverage   - Show test coverage analysis"
        echo "  functions  - List all library functions"
        echo "  test       - Run all tests"
        echo "  help       - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 report"
        echo "  $0 function get_absolute_path"
        echo "  $0 coverage"
        echo "  $0 test"
        ;;
esac