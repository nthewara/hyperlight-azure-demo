#!/usr/bin/env bash
# Deploy the Hyperlight demo via Bicep (subscription-scoped).
# Usage: ./deploy.sh <ssh-source-cidr> [pubkey-file]
set -euo pipefail

CIDR="${1:?Usage: ./deploy.sh <ssh-source-cidr> [pubkey-file]}"
PUBKEY_FILE="${2:-$HOME/.ssh/id_ed25519.pub}"
LOCATION="${LOCATION:-australiaeast}"
# Set the target subscription via env var or pre-select it with `az account set`.
SUB="${AZURE_SUBSCRIPTION_ID:-}"

PUBKEY="$(cat "$PUBKEY_FILE")"

if [[ -n "$SUB" ]]; then
  az account set --subscription "$SUB"
fi

az deployment sub create \
  --name "hyperlight-$(date +%s)" \
  --location "$LOCATION" \
  --template-file "$(dirname "$0")/main.bicep" \
  --parameters location="$LOCATION" sshSourceCidr="$CIDR" sshPublicKey="$PUBKEY" \
  --query "properties.outputs" -o json
