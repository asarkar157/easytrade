#!/bin/bash
# Enable Factory Crisis problem pattern
# This pattern prevents factory from producing new cards, blocking credit card orders

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "factory_crisis" "true"

