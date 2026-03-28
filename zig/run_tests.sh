#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_FILE="$SCRIPT_DIR/../tests.yaml"
BINARY="$SCRIPT_DIR/zig-out/bin/humanlang"

# Build
echo "Building humanlang (Zig)..."
cd "$SCRIPT_DIR"
zig build -Doptimize=ReleaseSafe 2>&1
echo ""

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

if [ ! -f "$TESTS_FILE" ]; then
    echo "ERROR: Tests file not found at $TESTS_FILE"
    exit 1
fi

PASS=0
FAIL=0
ERRORS=""

process_test() {
    local name="$1"
    local program="$2"
    local expected_output="$3"

    if [ -z "$name" ]; then
        return
    fi

    # Write program to temp file
    local tmpfile
    tmpfile=$(mktemp /tmp/humanlang_test_XXXXXX.hl)
    printf '%s' "$program" > "$tmpfile"

    # Run the interpreter
    local actual
    actual=$("$BINARY" "$tmpfile" 2>/dev/null) || true

    # Compare output (strip trailing whitespace/newlines)
    local expected
    expected=$(printf '%s' "$expected_output" | sed 's/[[:space:]]*$//')
    actual=$(printf '%s' "$actual" | sed 's/[[:space:]]*$//')

    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
        ERRORS+="--- FAIL: $name ---"$'\n'
        ERRORS+="  Expected: |$(printf '%s' "$expected" | head -5)|"$'\n'
        ERRORS+="  Actual:   |$(printf '%s' "$actual" | head -5)|"$'\n'
        ERRORS+=$'\n'
    fi

    rm -f "$tmpfile"
}

# Parse tests.yaml
current_name=""
current_program=""
current_output=""
in_program=false
in_output=false

while IFS= read -r line || [ -n "$line" ]; do
    # Check for test name
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.*)\" ]]; then
        # Run previous test if exists
        if [ -n "$current_name" ]; then
            process_test "$current_name" "$current_program" "$current_output"
        fi
        current_name="${BASH_REMATCH[1]}"
        current_program=""
        current_output=""
        in_program=false
        in_output=false
        continue
    fi

    # Check for program: |
    if [[ "$line" =~ ^[[:space:]]*program:[[:space:]]*\|[[:space:]]*$ ]]; then
        in_program=true
        in_output=false
        current_program=""
        continue
    fi

    # Check for output: |
    if [[ "$line" =~ ^[[:space:]]*output:[[:space:]]*\|[[:space:]]*$ ]]; then
        in_program=false
        in_output=true
        current_output=""
        continue
    fi

    # Check for output: (empty)
    if [[ "$line" =~ ^[[:space:]]*output:[[:space:]]*$ ]]; then
        in_program=false
        in_output=false
        current_output=""
        continue
    fi

    # Collect block content (indented by at least 6 spaces)
    if $in_program || $in_output; then
        if [[ "$line" =~ ^[[:space:]]{6} ]]; then
            content="${line#      }"
            if $in_program; then
                current_program+="$content"$'\n'
            elif $in_output; then
                current_output+="$content"$'\n'
            fi
        else
            in_program=false
            in_output=false
        fi
    fi
done < "$TESTS_FILE"

# Run the last test
if [ -n "$current_name" ]; then
    process_test "$current_name" "$current_program" "$current_output"
fi

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests"
echo "================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    printf '%s' "$ERRORS"
    exit 1
fi
