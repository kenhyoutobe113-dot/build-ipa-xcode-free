#!/usr/bin/env bash
# Archive with xcodebuild and export .ipa.
set -euo pipefail

SCHEME="${SCHEME:-YourAppScheme}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/App.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/ipa}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-ci/ExportOptions-appstore.plist}"

mkdir -p build

if [[ -n "${XCODE_WORKSPACE:-}" ]]; then
  XCODE_TARGET_ARGS=(-workspace "$XCODE_WORKSPACE")
elif [[ -n "${XCODE_PROJECT:-}" ]]; then
  XCODE_TARGET_ARGS=(-project "$XCODE_PROJECT")
else
  echo "Set XCODE_WORKSPACE or XCODE_PROJECT"
  exit 1
fi

echo "==> Archiving ${SCHEME} (${CONFIGURATION})"
xcodebuild clean archive \
  "${XCODE_TARGET_ARGS[@]}" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM}" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Apple Distribution}" \
  PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER:?Set PROVISIONING_PROFILE_SPECIFIER}"

echo "==> Exporting IPA"
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates

IPA_FILE="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' | head -n 1)"
if [[ -z "$IPA_FILE" ]]; then
  echo "No .ipa found in ${EXPORT_PATH}"
  exit 1
fi

echo "IPA ready: ${IPA_FILE}"
