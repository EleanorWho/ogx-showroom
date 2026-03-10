#!/bin/bash

set -euo pipefail

# Check if uv is available
if ! command -v uv &> /dev/null; then
  echo "ERROR: uv is required to run tests (see Prerequisites in README.md)"
  exit 1
fi

echo "=========================================="
echo "Running tests..."
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Running rag-demo.py..."
echo "=========================================="
echo ""

uv run "${SCRIPT_DIR}/scripts/rag-demo.py"

echo ""
echo "=========================================="
echo "Running responses-demo.py..."
echo "=========================================="
echo ""

uv run "${SCRIPT_DIR}/scripts/responses-demo.py"

# Check if SHOWROOM_OPENAI_API_KEY is configured
if [ -f ~/.lls_showroom ]; then
  # shellcheck source=/dev/null
  source ~/.lls_showroom
  if [ -n "${SHOWROOM_OPENAI_API_KEY:-}" ]; then
    echo ""
    echo "=========================================="
    echo "Running multi-agent-demo.py..."
    echo "=========================================="
    echo ""

    uv run "${SCRIPT_DIR}/scripts/multi-agent-demo.py"
  else
    echo ""
    echo "⊘ Skipping multi-agent-demo.py (SHOWROOM_OPENAI_API_KEY not configured)"
  fi
else
  echo ""
  echo "⊘ Skipping multi-agent-demo.py (SHOWROOM_OPENAI_API_KEY not configured)"
fi

echo ""
echo "✓ Tests completed successfully"
