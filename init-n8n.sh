#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SUBDOMAIN="${1:-}"
DO_TOKEN="${2:-}"

if [[ -z "$SUBDOMAIN" ]]; then
  echo "Usage: $0 <subdomain> [do_api_token]" >&2
  exit 1
fi

# Wait for apt to be free
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting on apt lock..." >&2
  sleep 2
done

apt-get update && apt-get upgrade -y
apt-get install -y docker.io docker-compose ufw curl jq

# Setup firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh http https
ufw --force enable

# (optional) Create swap
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# …then the rest of your Docker/Caddy/n8n install…
