#!/usr/bin/env bash
# Import distribution certificate + provisioning profile into a temporary CI keychain.
set -euo pipefail

: "${BUILD_CERTIFICATE_BASE64:?Set BUILD_CERTIFICATE_BASE64 (base64-encoded .p12)}"
: "${P12_PASSWORD:?Set P12_PASSWORD}"
: "${PROVISIONING_PROFILE_BASE64:?Set PROVISIONING_PROFILE_BASE64}"
: "${KEYCHAIN_PASSWORD:?Set KEYCHAIN_PASSWORD}"

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/app-signing.keychain-db"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

CERT_PATH="${RUNNER_TEMP:-/tmp}/build_certificate.p12"
echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$CERT_PATH"
security import "$CERT_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"

PROFILE_PATH="${RUNNER_TEMP:-/tmp}/build.mobileprovision"
echo "$PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< "$(security cms -D -i "$PROFILE_PATH")")"
cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision"

echo "Signing assets installed (profile UUID: ${PROFILE_UUID})"
