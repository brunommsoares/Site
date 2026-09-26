#!/usr/bin/env bash
# Deploys the site to EC2 over SSH: uploads the HTML files and runs
# server-setup.sh on the instance.
#
# Required env:
#   EC2_HOST          e.g. ec2-100-31-125-211.compute-1.amazonaws.com
#   EC2_USER          ubuntu | ec2-user
#   EC2_SSH_KEY_B64   the private key (.pem), base64-encoded on one line
# Optional env:
#   DOMAIN, CERTBOT_EMAIL   enable HTTPS with Let's Encrypt
set -euo pipefail

: "${EC2_HOST:?EC2_HOST is not set}"
: "${EC2_USER:?EC2_USER is not set}"
: "${EC2_SSH_KEY_B64:?EC2_SSH_KEY_B64 is not set}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="$(mktemp)"
trap 'rm -f "$KEY"' EXIT
printf '%s' "$EC2_SSH_KEY_B64" | base64 -d > "$KEY"
chmod 600 "$KEY"

SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "$EC2_USER@$EC2_HOST")

# Names nginx should answer to: the EC2 hostname and its public IP
EC2_IP="$(getent hosts "$EC2_HOST" | awk '{print $1; exit}' || true)"
EC2_NAMES="$EC2_HOST ${EC2_IP:-}"

echo "→ Uploading site to $EC2_HOST"
tar -C "$ROOT" -czf - landing.html index.html \
  | "${SSH[@]}" 'sudo mkdir -p /var/www/silver && sudo tar -xzf - -C /var/www/silver'

echo "→ Configuring nginx"
"${SSH[@]}" "sudo EC2_NAMES='$EC2_NAMES' DOMAIN='${DOMAIN:-}' CERTBOT_EMAIL='${CERTBOT_EMAIL:-}' bash -s" \
  < "$ROOT/deploy/server-setup.sh"

echo "✓ Deployed: http://$EC2_HOST/"
