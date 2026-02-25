#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SDK_HOME="${CONNECTIQ_SDK_HOME:-}"
MONKEYC=""
if [[ -n "$SDK_HOME" ]]; then
  MONKEYC="${SDK_HOME}/bin/monkeyc"
fi
KEY_PATH="${CONNECTIQ_KEY_PATH:-$HOME/.ciq/developer_key.der}"
OUTPUT_PATH="${ROOT_DIR}/bin/Stronglifts5x5.iq"

usage() {
  cat <<'EOF'
Build a Connect IQ submission package (.iq) for this app.

Usage:
  scripts/build-iq-package.sh -s sdk_home [-k key.der] [-o output.iq]

Options:
  -k  Path to developer/distribution key (.der)
  -o  Output .iq path (default: bin/Stronglifts5x5.iq)
  -s  Connect IQ SDK home path (required unless CONNECTIQ_SDK_HOME is set)
  -h  Show this help

Environment overrides:
  CONNECTIQ_KEY_PATH
  CONNECTIQ_SDK_HOME
EOF
}

while getopts ":k:o:s:h" opt; do
  case "$opt" in
    k) KEY_PATH="$OPTARG" ;;
    o) OUTPUT_PATH="$OPTARG" ;;
    s)
      SDK_HOME="$OPTARG"
      MONKEYC="${SDK_HOME}/bin/monkeyc"
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      echo "Missing value for -$OPTARG" >&2
      usage
      exit 2
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$SDK_HOME" ]]; then
  echo "SDK home is required." >&2
  echo "Pass -s <sdk_home> or set CONNECTIQ_SDK_HOME." >&2
  usage
  exit 1
fi

if [[ ! -x "$MONKEYC" ]]; then
  echo "monkeyc not found or not executable: $MONKEYC" >&2
  echo "Set -s <sdk_home> or CONNECTIQ_SDK_HOME." >&2
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Key file not found: $KEY_PATH" >&2
  echo "Set -k <path/to/key.der> or CONNECTIQ_KEY_PATH." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

echo "Building package:"
echo "  SDK:    $SDK_HOME"
echo "  Key:    $KEY_PATH"
echo "  Output: $OUTPUT_PATH"

"$MONKEYC" \
  -f "$ROOT_DIR/monkey.jungle" \
  -o "$OUTPUT_PATH" \
  -y "$KEY_PATH" \
  --package-app

echo "Done: $OUTPUT_PATH"
