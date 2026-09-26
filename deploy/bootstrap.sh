#!/usr/bin/env bash
# One-line install/update, run ON the EC2 instance (e.g. from the AWS console's
# EC2 Instance Connect browser terminal) — no SSH key needed:
#
#   curl -fsSL https://raw.githubusercontent.com/brunommsoares/Site/claude/wizardly-dijkstra-25nzpp/deploy/bootstrap.sh | sudo bash
#
# Downloads the site from GitHub into /var/www/silver and runs server-setup.sh.
# Optional env (pass after sudo): DOMAIN=silvercancer.com CERTBOT_EMAIL=you@example.com
set -euo pipefail

BRANCH="${BRANCH:-claude/wizardly-dijkstra-25nzpp}"
RAW="https://raw.githubusercontent.com/brunommsoares/Site/$BRANCH"
SITE_DIR=/var/www/silver

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo" >&2; exit 1; fi

echo "→ Downloading site ($BRANCH)"
mkdir -p "$SITE_DIR"
for f in landing.html index.html; do
  curl -fsSL "$RAW/$f" -o "$SITE_DIR/$f.tmp" && mv "$SITE_DIR/$f.tmp" "$SITE_DIR/$f"
done

# Public hostname and IP from instance metadata (IMDSv2), so nginx answers to both
TOKEN="$(curl -fsS -m 3 -X PUT http://169.254.169.254/latest/api/token \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null || true)"
md(){ curl -fsS -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1" 2>/dev/null || true; }
EC2_NAMES="$(md public-hostname) $(md public-ipv4)"
[ -z "${EC2_NAMES// /}" ] && EC2_NAMES="_"

echo "→ Configuring nginx"
curl -fsSL "$RAW/deploy/server-setup.sh" \
  | EC2_NAMES="$EC2_NAMES" DOMAIN="${DOMAIN:-}" CERTBOT_EMAIL="${CERTBOT_EMAIL:-}" bash

PUBLIC="$(md public-hostname)"
echo "✓ Live at: http://${PUBLIC:-<this-server>}/"
