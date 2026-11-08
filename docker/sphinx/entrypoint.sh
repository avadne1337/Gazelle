#!/bin/bash
# Render the Manticore config from env, build the indexes from MariaDB, then
# run searchd in the foreground. Index refresh over time is a cron job
# (indexer --rotate) and is left as a follow-up.
set -e

CONF=/etc/manticoresearch/manticore.conf
sed -e "s/__SQL_USER__/${GAZELLE_DB_USER}/g" \
    -e "s/__SQL_PASS__/${GAZELLE_DB_PASSWORD}/g" \
    /etc/manticoresearch/manticore.conf.tpl > "$CONF"

mkdir -p /var/lib/manticore /var/log/manticore /var/run/manticore

# Build all indexes from the database (ok to fail on first boot if empty).
indexer --config "$CONF" --all || echo "indexer: initial build reported issues (continuing)"

# Periodic full reindex so newly uploaded torrents become searchable.
# --rotate signals the running searchd to swap in the rebuilt indexes.
REINDEX_INTERVAL="${REINDEX_INTERVAL:-900}"
(
  while sleep "$REINDEX_INTERVAL"; do
    indexer --config "$CONF" --all --rotate 2>&1 | grep -iE "collected|ERROR" || true
  done
) &

exec searchd --config "$CONF" --nodetach
