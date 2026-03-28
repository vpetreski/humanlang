#!/usr/bin/env bash
#
# Test runner for the humanlang OCaml interpreter.
# Parses tests.yaml, runs each test case, and reports pass/fail.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_FILE="$PROJECT_DIR/tests.yaml"
BINARY="$SCRIPT_DIR/humanlang"

# --- Build ---
echo "Compiling humanlang.ml..."
cd "$SCRIPT_DIR"
ocamlopt -o humanlang humanlang.ml 2>&1
echo "Compilation successful."
echo ""

# --- Use Python to extract tests from YAML and run them ---
python3 - "$BINARY" "$TESTS_FILE" <<'PYEOF'
import sys, subprocess, os, tempfile

binary = sys.argv[1]
tests_file = sys.argv[2]

# Minimal YAML parser for the tests.yaml format
tests = []
current = None
field = None

with open(tests_file, 'r') as f:
    lines = f.readlines()

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.rstrip('\n')

    # New test entry
    if stripped.lstrip().startswith('- name:'):
        if current is not None:
            tests.append(current)
        name = stripped.split('name:', 1)[1].strip().strip('"').strip("'")
        current = {'name': name, 'program': '', 'output': ''}
        field = None
        i += 1
        continue

    # program: |
    if current is not None and stripped.lstrip().startswith('program:') and '|' in stripped:
        field = 'program'
        # Determine block indent from next line
        i += 1
        block_indent = None
        while i < len(lines):
            bline = lines[i].rstrip('\n')
            # Empty line is part of block
            if bline.strip() == '':
                current[field] += '\n'
                i += 1
                continue
            # Determine indent
            content = bline.lstrip(' ')
            indent = len(bline) - len(content)
            if block_indent is None:
                block_indent = indent
            if indent < block_indent:
                break
            current[field] += bline[block_indent:] + '\n'
            i += 1
        field = None
        continue

    # output: |
    if current is not None and stripped.lstrip().startswith('output:') and '|' in stripped:
        field = 'output'
        i += 1
        block_indent = None
        while i < len(lines):
            bline = lines[i].rstrip('\n')
            if bline.strip() == '':
                # Could be end of block or blank line in output
                # Check if next non-empty line is still indented
                j = i + 1
                while j < len(lines) and lines[j].strip() == '':
                    j += 1
                if j < len(lines):
                    next_line = lines[j].rstrip('\n')
                    next_content = next_line.lstrip(' ')
                    next_indent = len(next_line) - len(next_content)
                    if block_indent is not None and next_indent >= block_indent and not next_line.lstrip().startswith('- name:'):
                        current[field] += '\n'
                        i += 1
                        continue
                break
            content = bline.lstrip(' ')
            indent = len(bline) - len(content)
            if block_indent is None:
                block_indent = indent
            if indent < block_indent:
                break
            current[field] += bline[block_indent:] + '\n'
            i += 1
        field = None
        continue

    i += 1

if current is not None:
    tests.append(current)

# Run tests
passed = 0
failed = 0
fail_details = []

for test in tests:
    name = test['name']
    program = test['program']
    # YAML block scalars have a trailing newline; the program content is the text
    # Strip one trailing newline that YAML adds
    if program.endswith('\n'):
        program = program[:-1]
    expected = test['output']
    if expected.endswith('\n'):
        expected = expected[:-1]

    # Write to temp file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.hl', delete=False) as f:
        f.write(program)
        tmppath = f.name

    try:
        result = subprocess.run([binary, tmppath], capture_output=True, text=True, timeout=10)
        actual = result.stdout
        if actual.endswith('\n'):
            actual = actual[:-1]

        if actual == expected:
            passed += 1
            print(f"  PASS: {name}")
        else:
            failed += 1
            print(f"  FAIL: {name}")
            fail_details.append((name, expected, actual, result.stderr))
    except subprocess.TimeoutExpired:
        failed += 1
        print(f"  FAIL: {name} (timeout)")
        fail_details.append((name, expected, "<timeout>", ""))
    except Exception as e:
        failed += 1
        print(f"  FAIL: {name} (error: {e})")
        fail_details.append((name, expected, f"<error: {e}>", ""))
    finally:
        os.unlink(tmppath)

total = passed + failed
print()
print("=========================================")
print(f"Results: {passed} passed, {failed} failed, {total} total")
print("=========================================")

if fail_details:
    print()
    print("Failed tests:")
    print()
    for name, expected, actual, stderr in fail_details:
        print(f"--- FAIL: {name} ---")
        print(f"  Expected: {expected!r}")
        print(f"  Actual:   {actual!r}")
        if stderr:
            print(f"  Stderr:   {stderr.rstrip()}")
        print()
    sys.exit(1)
PYEOF
