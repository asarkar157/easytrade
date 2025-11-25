#!/bin/bash
# Enable Ergo Aggregator Slowdown problem pattern
# This pattern causes aggregators to receive slower responses

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/toggle-problem-pattern.sh" "ergo_aggregator_slowdown" "true"

