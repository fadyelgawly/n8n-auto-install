#!/usr/bin/env bash
# Fully automated n8n installer with Caddy (HTTPS) and optional DNS setup on DigitalOcean
set -euo pipefail
IFS=$'\n\t'

function usage() {
  echo "Usage: $0 <subdomain> <domain> [do_api_token]"
  echo "  <subdomain>     e.g. n8n.yourdomain.com"
  echo "  <domain>        base domain, e.g. yourdomain.com"
  echo "  [do_api_token]  (optional) DigitalOcean API token for automatic DNS record creation"
  exit 1
}

SUBDOMAIN="${1:-}"
DOMAIN="${2:-}"
DO_TOKEN="${3:-}"

if [[ -z "$SUBDOMAIN" || -z "$DOMAIN" ]]; then
  usage
fi

# Allow override of n8n basic-auth credentials via env vars
: "${N8N_USER:=yourUser}"
: "${N8N_PASSWORD:=yourPass}"

# Wait for any apt locks to clear
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for apt lock..." >&2
  sleep 2
done

# Update & install prerequisites
apt-get update && apt-get upgrade -y
apt-get install -y docker.io docker-compose ufw curl jq

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Configure UFW firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# Create 1G swap if none exists
if ! swapon --show | grep -q '/swapfile'; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Optional: create DNS A record via DigitalOcean API
if [[ -n "$DO_TOKEN" ]]; then
  echo "Creating DNS record for $SUBDOMAIN..."
  IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
  RECORD_NAME="${SUBDOMAIN%%.*}"
  curl -s -X POST "https://api.digitalocean.com/v2/domains/${DOMAIN}/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${DO_TOKEN}" \
    -d "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"data\":\"${IP}\",\"ttl\":1800}"
  echo "DNS record created: ${RECORD_NAME}.${DOMAIN} → ${IP}"
fi

# Prepare directories
DOCKER_USER="ubuntu"
APP_DIR="/home/${DOCKER_USER}/n8n"
mkdir -p "${APP_DIR}"
chown -R "${DOCKER_USER}":docker "${APP_DIR}"

# Write Docker Compose file
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

# Write Caddyfile for automatic TLS and reverse proxy
cat > "${APP_DIR}/Caddyfile" <<EOF
${SUBDOMAIN} {
  reverse_proxy n8n:5678
  log {
    output file /data/access.log
  }
}
EOF

# Launch the stack
cd "${APP_DIR}"
docker-compose up -d

echo "✅ Setup complete!"
echo "🔗 Visit: https://${SUBDOMAIN}"
echo "   Default n8n credentials: ${N8N_USER} / ${N8N_PASSWORD}"
echo "   Remember to change the default credentials!"