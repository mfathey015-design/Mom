#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

APP_NAME="MOHAMED-ELMASRY-TOOL"
ZIP_URL="${ELMASRY_TOOL_URL:-https://raw.githubusercontent.com/mfathey015-design/Mom/main/MOHAMED-ELMASRY-TOOL.zip}"
TMP_DIR="$(mktemp -d -t mohamed-elmasry-tool.XXXXXX)"
ZIP_FILE="$TMP_DIR/$APP_NAME.zip"
PACKAGE_DIR="$TMP_DIR/MOHAMED-ELMASRY-TOOL-PACKAGE"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
    printf '\033[91mError: %s\033[0m\n' "$*" >&2
    exit 1
}

command -v pkg >/dev/null 2>&1 || fail "This launcher must be run inside Termux."

pkg update -y
pkg install -y python unzip curl

curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
    -o "$ZIP_FILE" "$ZIP_URL" \
    || fail "Could not download the tool package."

unzip -oq "$ZIP_FILE" -d "$TMP_DIR" \
    || fail "The downloaded package is not a valid ZIP archive."

[ -d "$PACKAGE_DIR" ] || fail "The tool package folder was not found."
cd "$PACKAGE_DIR"

bash install.sh
exec bash run.sh
