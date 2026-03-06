#!/bin/bash

set -euo pipefail

echo "=========================================="
echo "Running tests..."
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "${SCRIPT_DIR}/scripts/rag-demo.py"

echo ""
echo "✓ Tests completed successfully"
