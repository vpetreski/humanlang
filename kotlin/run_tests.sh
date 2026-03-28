#!/bin/bash
# Test runner for humanlang Kotlin interpreter
# Parses tests.yaml, runs each test case, reports pass/fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_FILE="$PROJECT_DIR/tests.yaml"
KOTLIN_FILE="$SCRIPT_DIR/humanlang.kt"
JAR_FILE="$SCRIPT_DIR/humanlang.jar"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}=== humanlang Kotlin Interpreter Test Runner ===${NC}"
echo ""

# Step 1: Compile
echo -e "${YELLOW}Compiling humanlang.kt...${NC}"
if ! kotlinc "$KOTLIN_FILE" -include-runtime -d "$JAR_FILE" 2>"$TEMP_DIR/compile_errors.txt"; then
    echo -e "${RED}Compilation failed:${NC}"
    cat "$TEMP_DIR/compile_errors.txt"
    exit 1
fi
echo -e "${GREEN}Compilation successful.${NC}"
echo ""

# Step 2: Parse tests.yaml and run each test
PASSED=0
FAILED=0
ERRORS=0
TOTAL=0
FAILED_TESTS=""

# Parse tests.yaml using a simple state machine
current_name=""
current_program=""
current_output=""
in_program=false
in_output=false

run_test() {
    local name="$1"
    local program="$2"
    local expected="$3"

    TOTAL=$((TOTAL + 1))

    # Write program to temp file
    local prog_file="$TEMP_DIR/test_$TOTAL.hl"
    printf '%s' "$program" > "$prog_file"

    # Run the interpreter
    local actual
    local exit_code=0
    actual=$(java -jar "$JAR_FILE" "$prog_file" 2>"$TEMP_DIR/stderr_$TOTAL.txt") || exit_code=$?

    # Compare output
    # Both expected and actual should end with newline for proper comparison
    local expected_trimmed
    local actual_trimmed
    expected_trimmed=$(printf '%s' "$expected")
    actual_trimmed=$(printf '%s' "$actual")

    if [ "$actual_trimmed" = "$expected_trimmed" ]; then
        PASSED=$((PASSED + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAILED=$((FAILED + 1))
        FAILED_TESTS="${FAILED_TESTS}\n  - $name"
        echo -e "  ${RED}FAIL${NC} $name"
        echo "    Expected: $(echo "$expected_trimmed" | head -3)"
        echo "    Got:      $(echo "$actual_trimmed" | head -3)"
        if [ -s "$TEMP_DIR/stderr_$TOTAL.txt" ]; then
            echo "    Stderr:   $(head -3 "$TEMP_DIR/stderr_$TOTAL.txt")"
        fi
    fi
}

# Parse the YAML file
while IFS= read -r line || [ -n "$line" ]; do
    # Detect test name
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.*)\" ]]; then
        # If we have a previous test, run it
        if [ -n "$current_name" ]; then
            run_test "$current_name" "$current_program" "$current_output"
        fi
        current_name="${BASH_REMATCH[1]}"
        current_program=""
        current_output=""
        in_program=false
        in_output=false
        continue
    fi

    # Detect program block start
    if [[ "$line" =~ ^[[:space:]]*program:[[:space:]]*\|[[:space:]]*$ ]]; then
        in_program=true
        in_output=false
        current_program=""
        continue
    fi

    # Detect output block start
    if [[ "$line" =~ ^[[:space:]]*output:[[:space:]]*\|[[:space:]]*$ ]]; then
        in_program=false
        in_output=true
        current_output=""
        continue
    fi

    # Detect empty output (output: |  followed by next test or EOF)
    if [[ "$line" =~ ^[[:space:]]*output:[[:space:]]*$ ]]; then
        in_program=false
        in_output=false
        current_output=""
        continue
    fi

    # Collect program lines (indented by 6 spaces in YAML)
    if $in_program; then
        if [[ "$line" =~ ^[[:space:]]{6} ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            # Remove exactly 6 leading spaces
            local_line="${line#      }"
            if [ -n "$current_program" ]; then
                current_program="${current_program}
${local_line}"
            else
                current_program="${local_line}"
            fi
        else
            in_program=false
            # Re-process this line
            if [[ "$line" =~ ^[[:space:]]*output:[[:space:]]*\|[[:space:]]*$ ]]; then
                in_output=true
                current_output=""
            elif [[ "$line" =~ ^[[:space:]]*output:[[:space:]]*$ ]]; then
                in_output=false
                current_output=""
            fi
        fi
        continue
    fi

    # Collect output lines (indented by 6 spaces in YAML)
    if $in_output; then
        if [[ "$line" =~ ^[[:space:]]{6} ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            local_line="${line#      }"
            if [ -n "$current_output" ]; then
                current_output="${current_output}
${local_line}"
            else
                current_output="${local_line}"
            fi
        else
            in_output=false
        fi
        continue
    fi

done < "$TESTS_FILE"

# Don't forget the last test
if [ -n "$current_name" ]; then
    run_test "$current_name" "$current_program" "$current_output"
fi

# Summary
echo ""
echo -e "${BOLD}=== Results ===${NC}"
echo -e "Total:  $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "\n${RED}Failed tests:${NC}${FAILED_TESTS}"
    exit 1
else
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
fi
