#!/usr/bin/env bash
# Deploys the site to EC2 over SSH: uploads the HTML files and runs
# server-setup.sh on the instance.
#
# Required env:
#   EC2_HOST          e.g. ec2-100-31-125-211.compute-1.amazonaws.com
#   EC2_USER          ubuntu | ec2-user
#   EC2_SSH_KEY_FILE  path to the private key (.pem), or
#   EC2_SSH_KEY_B64   the private key, base64-encoded on one line (CI)
# Optional env:
#   DOMAIN, CERTBOT_EMAIL   enable HTTPS with Let's Encrypt
set -euo pipefail

: "${EC2_HOST:?EC2_HOST is not set}"
: "${EC2_USER:?EC2_USER is not set}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${EC2_SSH_KEY_FILE:-}" ]; then
  KEY="$EC2_SSH_KEY_FILE"
else
  : "${EC2_SSH_KEY_B64:?set EC2_SSH_KEY_FILE or EC2_SSH_KEY_B64}"
  KEY="$(mktemp)"
  trap 'rm -f "$KEY"' EXIT
  printf '%s' "$EC2_SSH_KEY_B64" | base64 -d > "$KEY"
  chmod 600 "$KEY"
fi

SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "$EC2_USER@$EC2_HOST")

# Names nginx should answer to: the EC2 hostname and its public IP
EC2_IP="$( (getent hosts "$EC2_HOST" 2>/dev/null || host "$EC2_HOST" 2>/dev/null) | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)"
EC2_NAMES="$EC2_HOST ${EC2_IP:-}"

echo "→ Uploading site to $EC2_HOST"
tar -C "$ROOT" -czf - landing.html index.html \
  | "${SSH[@]}" 'sudo mkdir -p /var/www/silver && sudo tar -xzf - -C /var/www/silver'

echo "→ Configuring nginx"
"${SSH[@]}" "sudo EC2_NAMES='$EC2_NAMES' DOMAIN='${DOMAIN:-}' CERTBOT_EMAIL='${CERTBOT_EMAIL:-}' bash -s" \
  < "$ROOT/deploy/server-setup.sh"

echo "✓ Deployed: http://$EC2_HOST/"
