#!/bin/bash
# Validate a Boutiques descriptor: first as JSON, then against the Boutiques schema.
#
# Usage: ./validate.sh <path/to/descriptor.json>
#
# Requires the `boutiques` package for `bosh`: pip install boutiques

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <path/to/descriptor.json>" >&2
    exit 2
fi

DESCRIPTOR_PATH="$1"

if [[ ! -f "$DESCRIPTOR_PATH" ]]; then
    echo "Error: no such file: ${DESCRIPTOR_PATH}" >&2
    exit 2
fi

if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON=python
else
    echo "Error: neither python3 nor python found on PATH" >&2
    exit 2
fi

if ! command -v bosh >/dev/null 2>&1; then
    echo "Error: bosh not found on PATH. Install it with: pip install boutiques" >&2
    exit 2
fi

echo "Validating that ${DESCRIPTOR_PATH} is a valid JSON file..."
"$PYTHON" -m json.tool "$DESCRIPTOR_PATH" >/dev/null

echo "Validating that ${DESCRIPTOR_PATH} is a valid Boutiques descriptor..."
bosh validate "$DESCRIPTOR_PATH"
