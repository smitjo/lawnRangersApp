#!/usr/bin/env bash
#
# One-command backend deploy: push backend/ to the Apps Script project and
# redeploy the SAME /exec Web App URL. Replaces the manual copy-paste + the
# Deploy → Manage deployments → New version dance.
#
# One-time setup is in backend/DEPLOY.md.
#
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root (where .clasp.json lives)

if ! command -v clasp >/dev/null 2>&1; then
  echo "✗ clasp isn't installed. See backend/DEPLOY.md (install Node, then: npm i -g @google/clasp)."
  exit 1
fi

echo "▶ Pushing backend/ → Apps Script…"
clasp push -f

ID_FILE="backend/.deployment-id"
if [ -s "$ID_FILE" ]; then
  DEPLOY_ID="$(tr -d '[:space:]' < "$ID_FILE")"
  echo "▶ Redeploying Web App deployment $DEPLOY_ID (keeps the same /exec URL)…"
  clasp deploy -i "$DEPLOY_ID" -d "deploy $(date '+%Y-%m-%d %H:%M')"
  echo "✅ Done — the /exec URL now serves the latest Code.gs."
else
  echo "ℹ No $ID_FILE yet. Here are your deployments:"
  clasp deployments
  echo
  echo "→ Copy the Web App deployment id (starts with 'AKfyc…') into $ID_FILE, then re-run this script."
fi
