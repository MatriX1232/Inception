#!/bin/bash
set -euo pipefail

ensure_root() {
	(( EUID == 0 )) || {
		printf 'Root privileges required. Please rerun with sudo.\n' >&2
		exit 1
	}
}

resolve_domain() {
	: "${DOMAIN_NAME:=localhost}"
	printf '%s\n' "$DOMAIN_NAME"
}

prepare_target() {
	local dir=$1
	mkdir -p "$dir"
	printf '%s\n' "$dir"
}

create_pair() {
	local domain=$1
	local folder=$2
	local key="$folder/nginx-selfsigned.key"
	local cert="$folder/nginx-selfsigned.crt"

	openssl req \
		-x509 \
		-nodes \
		-newkey rsa:2048 \
		-days 365 \
		-keyout "$key" \
		-out "$cert" \
		-subj "/C=US/ST=State/L=City/O=42/OU=student/CN=${domain}"

	printf 'Certificate ready for %s\nKey: %s\nCert: %s\n' "$domain" "$key" "$cert"
}

main() {
	ensure_root
	local domain
	domain=$(resolve_domain)
	local location
	location=$(prepare_target "/etc/ssl/private")
	create_pair "$domain" "$location"
}

main "$@"