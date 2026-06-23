#!/usr/bin/env bash
# Pack .app into .ipa using Payload/ folder (internal/ad-hoc style).
# Usage: APP_PATH=/path/to/App.app OUTPUT_IPA=build/App.ipa bash scripts/pack-ipa-payload.sh
set -euo pipefail

APP_PATH="${APP_PATH:-}"
OUTPUT_IPA="${OUTPUT_IPA:-build/output.ipa}"
WORK_DIR="${WORK_DIR:-build/ipa-payload-work}"

if [[ -z "$APP_PATH" ]]; then
  echo "Set APP_PATH to a .app bundle (e.g. build/DerivedData/.../HuyenThinksUron.app)"
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "APP_PATH not found: $APP_PATH"
  exit 1
fi

if [[ "$APP_PATH" != *.app ]]; then
  echo "APP_PATH must end with .app"
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ipa-payload.XXXXXX")"
PAYLOAD_DIR="${STAGING_DIR}/Payload"

mkdir -p "$PAYLOAD_DIR"
echo "==> Copying ${APP_NAME} -> Payload/"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

if [[ "$OUTPUT_IPA" != /* ]]; then
  OUTPUT_IPA="$(pwd)/$OUTPUT_IPA"
fi
mkdir -p "$(dirname "$OUTPUT_IPA")"
OUTPUT_IPA="$(cd "$(dirname "$OUTPUT_IPA")" && pwd)/$(basename "$OUTPUT_IPA")"
rm -f "$OUTPUT_IPA"

echo "==> Zipping Payload -> ${OUTPUT_IPA}"
(
  cd "$STAGING_DIR"
  zip -qr "$OUTPUT_IPA" Payload
)

rm -rf "$STAGING_DIR"
echo "IPA ready: ${OUTPUT_IPA} ($(du -h "$OUTPUT_IPA" | cut -f1))"
