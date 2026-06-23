#!/usr/bin/env bash
# Upload exported .ipa to App Store Connect (TestFlight / App Store review pipeline).
set -euo pipefail

: "${APP_STORE_CONNECT_API_KEY_ID:?Set APP_STORE_CONNECT_API_KEY_ID}"
: "${APP_STORE_CONNECT_ISSUER_ID:?Set APP_STORE_CONNECT_ISSUER_ID}"
: "${APP_STORE_CONNECT_API_KEY:?Set APP_STORE_CONNECT_API_KEY (contents of AuthKey_*.p8)}"

EXPORT_PATH="${EXPORT_PATH:-build/ipa}"
IPA_FILE="${IPA_FILE:-$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' | head -n 1)}"

if [[ -z "$IPA_FILE" || ! -f "$IPA_FILE" ]]; then
  echo "IPA not found. Run build-ipa.sh first."
  exit 1
fi

KEY_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEY_DIR"
KEY_FILE="${KEY_DIR}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
printf '%s' "$APP_STORE_CONNECT_API_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

echo "==> Uploading ${IPA_FILE} to App Store Connect"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

echo "Upload finished. Check processing status in App Store Connect."
