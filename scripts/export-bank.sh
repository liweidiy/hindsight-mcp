#!/usr/bin/env bash
# Export one bank as a ZIP archive, then verify it opened.
# Usage: ./export-bank.sh <bank-id> [output.zip]
#
# Do NOT source the service EnvironmentFile first — bash will corrupt
# HINDSIGHT_API_LLM_EXTRA_BODY and the CLI fails while loading its config.
set -euo pipefail

ADMIN="${HINDSIGHT_ADMIN:-$HOME/.venvs/hindsight/bin/hindsight-admin}"
BANK="${1:?usage: export-bank.sh <bank-id> [output.zip]}"
OUT="${2:-$HOME/.hermes/export-bank-${BANK}-$(date +%Y%m%d).zip}"

"$ADMIN" export-bank -b "$BANK" -o "$OUT"

echo "exported bank '$BANK' -> $OUT"
unzip -l "$OUT" | tail -n 15
