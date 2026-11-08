#!/bin/bash
# Runs Gazelle's maintenance scripts on an interval (the Docker equivalent of the
# schedule.php / peerupdate.php cron jobs in docs/INSTALL.txt). Uses the same
# gazelle-php image, so it has the code, extensions, DB, cache and tracker access.
set -u

cd /var/www/gazelle
INTERVAL="${CRON_INTERVAL:-900}"   # 15 minutes

if [ -z "${SCHEDULE_KEY:-}" ]; then
    echo "[cron] SCHEDULE_KEY not set; schedule/peerupdate would 403. Exiting." >&2
    exit 1
fi

echo "[cron] starting; schedule.php + peerupdate.php every ${INTERVAL}s"
run() {  # run <script> with a hard timeout so a hung task can't wedge the loop
    echo "[cron] $(date -u +%FT%TZ) $1"
    timeout 600 php "/var/www/gazelle/$1" "$SCHEDULE_KEY" 2>&1 | tail -n 5
    local rc=${PIPESTATUS[0]}
    [ "$rc" = 124 ] && echo "[cron] $1 timed out after 600s"
}

while true; do
    run schedule.php
    run peerupdate.php
    sleep "$INTERVAL"
done
