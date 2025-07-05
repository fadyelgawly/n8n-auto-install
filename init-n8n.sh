#!/usr/bin/env bash
set -e

SUBDOMAIN="$1"
DOCKER_USER="ubuntu"
APP_DIR="/home/${DOCKER_USER}/n8n"

# 1) System prep
apt-get update && apt-get upgrade -y
apt-get install -y docker.io docker-compose curl

# 2) Ensure ubuntu can run docker
usermod -aG docker "$DOCKER_USER"

# 3) Create app directory
mkdir -p "$APP_DIR"
chown -R "$DOCKER_USER":docker "$APP_DIR"

# 4) Write docker-compose.yml
cat > "$APP_DIR/docker-compose.yml" <<EOF
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
      - N8N_BASIC_AUTH_USER=yourUser        # ← customize
      - N8N_BASIC_AUTH_PASSWORD=yourPass    # ← customize

volumes:
  caddy_data:
  caddy_config:
EOF

# 5) Write Caddyfile with the passed-in subdomain
cat > "$APP_DIR/Caddyfile" <<EOF
${SUBDOMAIN} {
  reverse_proxy n8n:5678
  log {
    output file /data/access.log
  }
}
EOF

# 6) Launch containers
cd "$APP_DIR"
docker-compose up -d
