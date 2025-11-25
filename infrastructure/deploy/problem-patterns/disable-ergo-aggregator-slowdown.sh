#!/bin/bash
# Disable Ergo Aggregator Slowdown problem pattern

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "ergo_aggregator_slowdown" "false"

