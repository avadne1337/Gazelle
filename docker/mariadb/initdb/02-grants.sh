#!/bin/bash
# Runs once, on first DB init, after gazelle.sql (which creates the `gazelle`
# database). Creates the application user from env vars so no secret is baked
# into a committed file.
set -e
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
	CREATE USER IF NOT EXISTS '${GAZELLE_DB_USER}'@'%' IDENTIFIED BY '${GAZELLE_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON gazelle.* TO '${GAZELLE_DB_USER}'@'%';
	FLUSH PRIVILEGES;
EOSQL
