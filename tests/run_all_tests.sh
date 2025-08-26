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

# Find and run all test files
for test_file in test_*.sh; do
    if [ -f "$test_file" ] && [ "$test_file" != "test_framework.sh" ]; then
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        
        echo -e "${YELLOW}Running $test_file...${NC}"
        echo ""
        
        if bash "$test_file"; then
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