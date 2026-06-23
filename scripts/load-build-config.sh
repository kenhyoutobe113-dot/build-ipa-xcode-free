#!/usr/bin/env bash
# Export tool/build-config.json fields as shell env vars (used by GitHub Actions).
set -euo pipefail

CONFIG="${1:-tool/build-config.json}"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing $CONFIG — run run.ps1 locally first."
  exit 1
fi

export_json() {
  python3 - "$CONFIG" "$1" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
print(cfg[sys.argv[2]])
PY
}

GITHUB_ENV="${GITHUB_ENV:-}"
write_env() {
  local key="$1" val="$2"
  export "$key=$val"
  if [[ -n "$GITHUB_ENV" ]]; then
    echo "$key=$val" >> "$GITHUB_ENV"
  fi
}

write_env XCODE_ZIP "$(export_json "$CONFIG" xcodeZip)"
write_env XCODE_SRC "$(export_json "$CONFIG" xcodeSrc)"
write_env XCODE_PROJECT "$(export_json "$CONFIG" xcodeProject)"
write_env SCHEME "$(export_json "$CONFIG" scheme)"
write_env APP_NAME "$(export_json "$CONFIG" appName)"
write_env OUTPUT_IPA "Xcode-Output/$(export_json "$CONFIG" outputIpa)"
write_env ARTIFACT_NAME "$(export_json "$CONFIG" artifactName)"

echo "Loaded build config from $CONFIG"
