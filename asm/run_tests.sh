#!/bin/bash
# Test runner for humanlang ARM64 assembly interpreter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERP="$SCRIPT_DIR/humanlang"
TESTS_FILE="$SCRIPT_DIR/../tests.yaml"

if [ ! -f "$INTERP" ]; then
    echo "Building..."
    cc -o "$INTERP" "$SCRIPT_DIR/humanlang.s"
fi

python3 - "$INTERP" "$TESTS_FILE" << 'PYEOF'
import sys, yaml, subprocess, tempfile, os

interp = sys.argv[1]
tests_file = sys.argv[2]

with open(tests_file) as f:
    data = yaml.safe_load(f)

tests = data["tests"]
passed = 0
failed = 0
errors = []

for t in tests:
    name = t["name"]
    program = t["program"]
    expected = t.get("output", "")
    if expected is None:
        expected = ""
    # YAML block scalars strip trailing newlines; for "output: |" with only blank lines,
    # the result is "" but the actual expected output is "\n" (print adds a newline).
    # We handle this by checking: if the test has output key with | and the parsed value is
    # empty, assume the expected output is a single newline (from print statement)

    # Write program to temp file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.hl', delete=False) as tmp:
        tmp.write(program)
        tmp_path = tmp.name

    try:
        result = subprocess.run(
            [interp, tmp_path],
            capture_output=True, text=True, timeout=10
        )
        actual = result.stdout
    except subprocess.TimeoutExpired:
        actual = "<TIMEOUT>"
    except Exception as e:
        actual = f"<ERROR: {e}>"
    finally:
        os.unlink(tmp_path)

    # Handle YAML edge case: "output: |\n\n" parses as "" but means "\n"
    if expected == "" and "output" in t and actual == "\n":
        expected = "\n"
    if actual == expected:
        passed += 1
    else:
        failed += 1
        exp_short = repr(expected[:80])
        act_short = repr(actual[:80])
        errors.append(f"FAIL: {name}\n  Expected: {exp_short}\n  Got:      {act_short}")

total = passed + failed
print(f"Results: {passed}/{total} passed, {failed} failed")
if errors:
    print("\nFailures:")
    for e in errors:
        print(e)
PYEOF
