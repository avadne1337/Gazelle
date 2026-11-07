#!/bin/bash
# Render ocelot.conf from environment (secrets come from the compose .env) and
# launch the tracker. listen_port 2710 matches Gazelle's TRACKER_PORT / ANNOUNCE_URL.
set -e

CONF=/etc/ocelot/ocelot.conf
mkdir -p /etc/ocelot

cat > "$CONF" <<EOF
listen_port         = 2710
max_connections     = 128
max_middlemen       = 20000
max_read_buffer     = 4096
connection_timeout  = 10
keepalive_timeout   = 0
announce_interval   = 1800
max_request_size    = 4096
numwant_limit       = 50
request_log_size    = 500

mysql_host          = ${MYSQL_HOST}
mysql_username      = ${MYSQL_USER}
mysql_password      = ${MYSQL_PASSWORD}
mysql_db            = ${MYSQL_DB}

report_password     = ${TRACKER_REPORTKEY}
site_password       = ${TRACKER_SECRET}

peers_timeout       = 7200
del_reason_lifetime = 86400
reap_peers_interval = 1800
schedule_interval   = 3

readonly            = false
EOF

exec ocelot -c "$CONF"
