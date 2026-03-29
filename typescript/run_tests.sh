#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Install dependencies
echo "Installing dependencies..."
npm install --silent 2>/dev/null

echo ""
echo "Running humanlang test suite..."
echo ""

npx tsx run_tests_impl.ts
