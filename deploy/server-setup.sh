#!/usr/bin/env bash
# Runs ON the EC2 instance (as root, via `sudo bash -s`).
# Idempotent: installs nginx, writes the site config and reloads it.
# Optional env: DOMAIN (e.g. silvercancer.com) + CERTBOT_EMAIL to enable HTTPS.
set -euo pipefail

SITE_DIR=/var/www/silver
EC2_NAMES="${EC2_NAMES:-}"
DOMAIN="${DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"

# --- Install nginx ---------------------------------------------------------
if ! command -v nginx >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y nginx
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y nginx
  elif command -v yum >/dev/null 2>&1; then
    yum install -y nginx
  else
    echo "No supported package manager found" >&2; exit 1
  fi
fi
# Ubuntu/Debian ship a default site that would win over ours
rm -f /etc/nginx/sites-enabled/default
systemctl enable --now nginx

mkdir -p "$SITE_DIR"
chmod -R a+rX "$SITE_DIR"

# --- nginx site config -----------------------------------------------------
NAMES="$EC2_NAMES"
[ -n "$DOMAIN" ] && NAMES="$NAMES $DOMAIN www.$DOMAIN"

# Don't clobber a config certbot has already upgraded to HTTPS
CONF=/etc/nginx/conf.d/silver.conf
if [ ! -f "$CONF" ] || ! grep -q 'managed by Certbot' "$CONF"; then
  cat > "$CONF" <<EOF
server {
    listen 80;
    server_name $NAMES;

    root $SITE_DIR;
    index landing.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi

nginx -t
systemctl reload nginx
echo "nginx serving $SITE_DIR for: $NAMES"

# --- HTTPS (only when a domain is given and already points here) -----------
if [ -n "$DOMAIN" ] && [ -n "$CERTBOT_EMAIL" ]; then
  if ! command -v certbot >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get install -y certbot python3-certbot-nginx
    else
      dnf install -y certbot python3-certbot-nginx
    fi
  fi
  certbot --nginx --non-interactive --agree-tos --redirect \
    -m "$CERTBOT_EMAIL" -d "$DOMAIN" -d "www.$DOMAIN" \
    || echo "certbot failed — check that $DOMAIN and www.$DOMAIN point to this instance" >&2
fi
