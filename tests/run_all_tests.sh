#!/bin/bash

# Main test runner for all jmux library tests

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}          jmux Library Tests           ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Parse command line arguments
INTEGRATION_ONLY=false
UNIT_ONLY=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --integration)
            INTEGRATION_ONLY=true
            shift
            ;;
        --unit)
            UNIT_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--integration] [--unit] [--verbose]"
            exit 1
            ;;
    esac
done

# Find and run all test files
for test_file in test_*.sh; do
    if [ -f "$test_file" ] && [ "$test_file" != "test_framework.sh" ]; then
        # Filter based on test type
        if [ "$test_file" = "test_integration.sh" ] || [ "$test_file" = "test_file_opening.sh" ]; then
            is_integration=true
        else
            is_integration=false
        fi

        # Skip if filtering is enabled
        if [ "$INTEGRATION_ONLY" = true ] && [ "$is_integration" = false ]; then
            continue
        fi
        if [ "$UNIT_ONLY" = true ] && [ "$is_integration" = true ]; then
            continue
        fi

        TOTAL_SUITES=$((TOTAL_SUITES + 1))

        echo -e "${YELLOW}Running $test_file...${NC}"
        if [ "$VERBOSE" = true ]; then
            echo ""
        fi

        if [ "$VERBOSE" = true ]; then
            bash "$test_file"
            result=$?
        else
            if bash "$test_file" >/dev/null 2>&1; then
                result=0
            else
                result=1
            fi
        fi

        if [ $result -eq 0 ]; then
            PASSED_SUITES=$((PASSED_SUITES + 1))
            echo -e "${GREEN}✓ $test_file PASSED${NC}"
        else
            FAILED_SUITES=$((FAILED_SUITES + 1))
            echo -e "${RED}✗ $test_file FAILED${NC}"
        fi

        echo ""
        echo "----------------------------------------"
        echo ""
    fi
done

# Final summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}             Final Summary              ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Test Suites: $TOTAL_SUITES"
echo -e "${GREEN}Passed:      $PASSED_SUITES${NC}"
echo -e "${RED}Failed:      $FAILED_SUITES${NC}"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}🎉 All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some test suites failed.${NC}"
    exit 1
fi