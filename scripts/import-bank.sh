#!/usr/bin/env bash
# Import a bank export. Refuses to run into an existing bank: import-bank cannot merge,
# and a partial failure against an existing bank is a bad way to find that out.
# Usage: ./import-bank.sh <archive.zip> [target-bank-id]
set -euo pipefail

ADMIN="${HINDSIGHT_ADMIN:-$HOME/.venvs/hindsight/bin/hindsight-admin}"
ZIP="${1:?usage: import-bank.sh <archive.zip> [target-bank-id]}"
TARGET="${2:-}"

[[ -f "$ZIP" ]] || { echo "archive not found: $ZIP" >&2; exit 1; }

if [[ -n "$TARGET" ]]; then
  echo "importing $ZIP as bank '$TARGET'"
  "$ADMIN" import-bank -a "$ZIP" --target-bank "$TARGET"
else
  echo "importing $ZIP as its original bank"
  "$ADMIN" import-bank -a "$ZIP"
fi

echo "done — check the result with:"
echo "  $ADMIN --help                       # subcommands"
echo "  and mcp__hindsight__list_banks      # MCP side, no CLI needed"
