#!/bin/bash

DESCRIPTOR_PATH="$1"

echo "Validating that ${DESCRIPTOR_PATH} is a valid JSON file..."
python -m json.tool "$DESCRIPTOR_PATH" >/dev/null

echo "Validating that ${DESCRIPTOR_PATH} is a valid Boutiques descriptor..."
bosh validate "$DESCRIPTOR_PATH"
