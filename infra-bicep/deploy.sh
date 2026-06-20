#!/usr/bin/env bash
# Deploy the Hyperlight demo via Bicep (subscription-scoped).
# Usage: ./deploy.sh <ssh-source-cidr> [pubkey-file]
set -euo pipefail

CIDR="${1:?Usage: ./deploy.sh <ssh-source-cidr> [pubkey-file]}"
PUBKEY_FILE="${2:-$HOME/.ssh/id_ed25519.pub}"
LOCATION="australiaeast"
SUB="b9d87a00-a4d8-47d9-84a2-cfd7a9d745d2"

PUBKEY="$(cat "$PUBKEY_FILE")"

az account set --subscription "$SUB"

az deployment sub create \
  --name "hyperlight-$(date +%s)" \
  --location "$LOCATION" \
  --template-file "$(dirname "$0")/main.bicep" \
  --parameters location="$LOCATION" sshSourceCidr="$CIDR" sshPublicKey="$PUBKEY" \
  --query "properties.outputs" -o json
