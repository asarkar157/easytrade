#!/bin/bash
# Disable Factory Crisis problem pattern

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "factory_crisis" "false"

