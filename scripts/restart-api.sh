#!/usr/bin/env bash
# Restart the Hindsight API service and check that it came back clean.
# Budget ~20s of downtime; worker tasks in flight do not survive a restart.
set -euo pipefail

ADMIN="${HINDSIGHT_ADMIN:-$HOME/.venvs/hindsight/bin/hindsight-admin}"
UNIT="${HINDSIGHT_UNIT:-hindsight-api.service}"

systemctl --user restart "$UNIT"
sleep 3
systemctl --user status --no-pager "$UNIT" | head -n 12
journalctl --user -u "${UNIT%.service}" -n 20 --no-pager | tail -n 20

echo '--- worker status (a task can land in "failed" after a restart) ---'
"$ADMIN" worker-status || true
