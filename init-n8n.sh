#!/usr/bin/env bash
# Fully automated, idempotent n8n installer with Caddy (HTTPS) and optional DNS setup
# Usage: init-n8n.sh <subdomain> <domain> [do_api_token]
set -euo pipefail
IFS=$'\n\t'



echo "→ Starting n8n setup for ${SUBDOMAIN} 

SUBDOMAIN="${1:-}"
DOMAIN="${2:-}"
DO_TOKEN="${3:-}"

if [[ -z "$SUBDOMAIN" ]]; then
  usage
fi

# Optional basic auth override
: "${N8N_USER:=yourUser}"
: "${N8N_PASSWORD:=yourPass}"

echo "→ Starting n8n setup for ${SUBDOMAIN} on ${DOMAIN}…"
echo "→ Repairing interrupted dpkg installs (if any)…"
dpkg --configure -a || true

echo "→ Waiting for any apt locks to clear…"
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "   …lock held, sleeping 2s"
  sleep 2
done

echo "→ Updating & upgrading system…"
apt-get update && apt-get upgrade -y

echo "→ Installing prerequisites…"
apt-get install -y docker.io docker-compose ufw curl jq

echo "→ Adding ubuntu to docker group…"
usermod -aG docker ubuntu

echo "→ Configuring UFW…"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

echo "→ Ensuring 1G swap exists…"
if ! swapon --show | grep -q '/swapfile'; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

if [[ -n "$DO_TOKEN" ]]; then
  echo "→ Creating DNS A-record for ${SUBDOMAIN}…"
  IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
  RECORD_NAME="${SUBDOMAIN%%.*}"
  curl -s -X POST "https://api.digitalocean.com/v2/domains/${DOMAIN}/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${DO_TOKEN}" \
    -d "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"data\":\"${IP}\",\"ttl\":1800}"
  echo "   → ${RECORD_NAME}.${DOMAIN} → ${IP}"
fi

echo "→ Setting up application directory…"
DOCKER_USER="ubuntu"
APP_DIR="/home/${DOCKER_USER}/n8n"
mkdir -p "${APP_DIR}"
chown -R "${DOCKER_USER}":docker "${APP_DIR}"

echo "→ Writing docker-compose.yml…"
cat > "${APP_DIR}/docker-compose.yml" <<EOF
version: '3.8'
services:
  caddy:
    image: caddy:2
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/data
      - caddy_config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile

  n8n:
    image: n8nio/n8n
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}

volumes:
  caddy_data:
  caddy_config:
EOF

echo "→ Writing Caddyfile for ${SUBDOMAIN}…"
cat > "${APP_DIR}/Caddyfile" <<EOF
${SUBDOMAIN} {
  reverse_proxy n8n:5678
  log {
    output file /data/access.log
  }
}
EOF

echo "→ Starting Docker stack…"
cd "${APP_DIR}"
docker-compose up -d

echo "✅ Setup complete!"
echo "🔗 Visit: https://${SUBDOMAIN}"
echo "   Credentials: ${N8N_USER} / ${N8N_PASSWORD}"
