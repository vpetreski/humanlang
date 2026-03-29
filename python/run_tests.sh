#!/usr/bin/env bash
# run_tests.sh — Parse tests.yaml and run each test case against the humanlang interpreter.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERP="$SCRIPT_DIR/humanlang.py"
TESTS_FILE="$SCRIPT_DIR/../tests.yaml"

exec python3 - "$TESTS_FILE" "$INTERP" << 'PYEOF'
import json, subprocess, sys, os, tempfile, re

tests_file = sys.argv[1]
interp = sys.argv[2]

# ---------------------------------------------------------------------------
# Parse tests.yaml (no PyYAML dependency)
# ---------------------------------------------------------------------------

def parse_tests_yaml(path):
    tests = []
    current = None
    with open(path) as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip blank, comments, preamble
        if not stripped or stripped.startswith('#') or stripped.startswith('version:') or stripped == 'tests:':
            i += 1
            continue

        # New test case
        m = re.match(r'^\s*- name:\s*"(.+)"', line)
        if m:
            if current is not None:
                tests.append(current)
            current = {'name': m.group(1), 'program': '', 'output': ''}
            i += 1
            continue

        # program: | or output: |
        m = re.match(r'^\s+(program|output):\s*(\|)?\s*$', line)
        if m and current is not None:
            field = m.group(1)
            is_block = m.group(2) == '|'
            if is_block:
                i += 1
                block_lines = []
                # Find indent of first content line
                content_indent = None
                while i < len(lines):
                    bl = lines[i]
                    if bl.strip() == '':
                        block_lines.append('')
                        i += 1
                        continue
                    bl_indent = len(bl) - len(bl.lstrip())
                    if content_indent is None:
                        content_indent = bl_indent
                    if bl_indent >= content_indent:
                        block_lines.append(bl[content_indent:].rstrip('\n'))
                        i += 1
                    else:
                        break
                # Trim trailing empty lines (YAML block scalar chomping)
                while block_lines and block_lines[-1] == '':
                    block_lines.pop()
                current[field] = '\n'.join(block_lines) + '\n' if block_lines else ''
            else:
                current[field] = ''
                i += 1
            continue

        i += 1

    if current is not None:
        tests.append(current)
    return tests

# Try PyYAML first, fall back to manual parser
try:
    import yaml
    with open(tests_file) as f:
        data = yaml.safe_load(f)
    tests = data['tests']
    # Normalize: PyYAML may return None for empty output
    for t in tests:
        if t.get('output') is None:
            t['output'] = ''
except ImportError:
    tests = parse_tests_yaml(tests_file)

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------

tmpdir = tempfile.mkdtemp()
passed = 0
failed = 0
failures = []

for test in tests:
    name = test['name']
    program = test['program']
    expected = test.get('output', '')

    # Write program to temp file
    prog_file = os.path.join(tmpdir, 'test.hl')
    with open(prog_file, 'w') as f:
        f.write(program)

    # Run interpreter
    try:
        result = subprocess.run(
            ['python3', interp, prog_file],
            capture_output=True, text=True, timeout=10
        )
        actual = result.stdout
    except subprocess.TimeoutExpired:
        actual = ''

    # Strip trailing whitespace/newlines for comparison (matches YAML block scalar behavior)
    actual_cmp = actual.rstrip()
    expected_cmp = expected.rstrip()

    if actual_cmp == expected_cmp:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        failures.append((name, expected, actual))
        print(f"  FAIL  {name}")
        print(f"        expected: {expected_cmp!r}")
        print(f"        actual:   {actual_cmp!r}")
        if result.stderr:
            print(f"        stderr:   {result.stderr.strip()}")

# Cleanup
import shutil
shutil.rmtree(tmpdir, ignore_errors=True)

total = passed + failed
print()
print(f"Results: {passed}/{total} passed, {failed} failed")

if failed > 0:
    sys.exit(1)
PYEOF
