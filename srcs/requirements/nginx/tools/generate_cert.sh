#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Use sudo." >&2
  exit 1
fi

DOMAIN_NAME=${DOMAIN_NAME:-localhost}
CERT_DIR="/etc/ssl/private"

mkdir -p "$CERT_DIR"

KEY_FILE="$CERT_DIR/nginx-selfsigned.key"
CERT_FILE="$CERT_DIR/nginx-selfsigned.crt"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/C=US/ST=State/L=City/0=42/OU=student/CN=$DOMAIN_NAME"

# Restrict permissions: private key readable only by root
chmod 600 "$KEY_FILE" || true
chmod 644 "$CERT_FILE" || true

echo "SSL Certificate and Key generated:"
echo "Key: $KEY_FILE"
echo "CERTIFICATE: $CERT_FILE"