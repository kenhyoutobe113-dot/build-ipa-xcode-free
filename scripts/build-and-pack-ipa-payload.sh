#!/usr/bin/env bash
# Build Unity-iPhone project on macOS, then pack .ipa via Payload/ method.
set -euo pipefail

XCODE_PROJECT="${XCODE_PROJECT:-Unity-iPhone.xcodeproj}"
SCHEME="${SCHEME:-Unity-iPhone}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
APP_NAME="${APP_NAME:-HuyenThoaiUron.app}"
OUTPUT_IPA="${OUTPUT_IPA:-Xcode-Output/HuyenThoaiUron.ipa}"

echo "==> xcodebuild (generic iOS device)"
xcodebuild \
  -project "$XCODE_PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"} \
  ${CODE_SIGN_IDENTITY:+CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"} \
  ${PROVISIONING_PROFILE_SPECIFIER:+PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER"} \
  CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Manual}" \
  build

APP_PATH="$(find "$DERIVED_DATA" -type d -name "$APP_NAME" | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Built .app not found (expected name: ${APP_NAME})"
  find "$DERIVED_DATA" -type d -name "*.app" | head -5
  exit 1
fi

echo "==> Found app: ${APP_PATH}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$APP_PATH" OUTPUT_IPA="$OUTPUT_IPA" bash "$SCRIPT_DIR/pack-ipa-payload.sh"
