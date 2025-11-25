#!/bin/bash
# Disable DB Not Responding problem pattern

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "db_not_responding" "false"

