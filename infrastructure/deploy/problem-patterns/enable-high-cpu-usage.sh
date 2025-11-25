#!/bin/bash
# Enable High CPU Usage problem pattern
# This pattern causes broker-service slowdown and high CPU usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "high_cpu_usage" "true"

