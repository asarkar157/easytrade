#!/bin/bash
# Enable DB Not Responding problem pattern
# This pattern prevents new trades from being created

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "db_not_responding" "true"

