#!/bin/bash
# Disable High CPU Usage problem pattern

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "high_cpu_usage" "false"

