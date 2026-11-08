#!/bin/bash
# Generate a self-signed TLS certificate for the Gazelle nginx service.
# Idempotent: does nothing if the cert already exists (delete to regenerate).
# Usage: ./gen-cert.sh [host-or-ip]   (default: 192.168.1.111)
set -e

CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
HOST="${1:-192.168.1.111}"
mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/gazelle.crt" ] && [ -f "$CERT_DIR/gazelle.key" ]; then
    echo "cert already present in $CERT_DIR (delete gazelle.crt/key to regenerate)"
    exit 0
fi

# SAN as an IP when $HOST looks like an IPv4 address, otherwise as a DNS name.
if echo "$HOST" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    SAN="IP:$HOST,DNS:localhost"
else
    SAN="DNS:$HOST,DNS:localhost"
fi

openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "$CERT_DIR/gazelle.key" -out "$CERT_DIR/gazelle.crt" \
    -subj "/CN=$HOST" -addext "subjectAltName=$SAN"
chmod 600 "$CERT_DIR/gazelle.key"
echo "generated self-signed cert for $HOST (SAN: $SAN) in $CERT_DIR"
