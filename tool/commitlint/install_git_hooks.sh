#!/usr/bin/env bash
set -euo pipefail

git config --local core.hooksPath .githooks
echo "Configured local Git hooks path to .githooks"
