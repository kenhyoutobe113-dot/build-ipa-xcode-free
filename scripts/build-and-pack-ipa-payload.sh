#!/usr/bin/env bash
# Build Unity-iPhone project on macOS, then pack .ipa via Payload/ method.
# UNSIGNED_BUILD=1 -> no p12/profile needed; user re-signs IPA locally.
set -euo pipefail

XCODE_PROJECT="${XCODE_PROJECT:-Unity-iPhone.xcodeproj}"
SCHEME="${SCHEME:-Unity-iPhone}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
APP_NAME="${APP_NAME:-HuyenThoaiUron.app}"
OUTPUT_IPA="${OUTPUT_IPA:-Xcode-Output/HuyenThoaiUron.ipa}"
UNSIGNED_BUILD="${UNSIGNED_BUILD:-1}"

if [[ "$UNSIGNED_BUILD" == "1" ]]; then
  echo "==> xcodebuild UNSIGNED (Payload IPA for user re-signing)"
  xcodebuild \
    -project "$XCODE_PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    CODE_SIGN_STYLE=Manual \
    EXPANDED_CODE_SIGN_IDENTITY="-" \
    build
else
  echo "==> xcodebuild SIGNED (generic iOS device)"
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
fi

APP_PATH="$(find "$DERIVED_DATA" -type d -name "$APP_NAME" | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Built .app not found (expected name: ${APP_NAME})"
  find "$DERIVED_DATA" -type d -name "*.app" | head -5
  exit 1
fi

echo "==> Found app: ${APP_PATH}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$APP_PATH" OUTPUT_IPA="$OUTPUT_IPA" bash "$SCRIPT_DIR/pack-ipa-payload.sh"

if [[ "$UNSIGNED_BUILD" == "1" ]]; then
  echo ""
  echo "NOTE: IPA is UNSIGNED. Install only after re-signing with a personal certificate."
  echo "  Windows: Sideloadly, 3uTools, ESign"
  echo "  iOS/Mac: AltStore, Sideloadly"
fi
