#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

APP_DIR="$HOME/elmasry-vip-tool"
ZIP_URL="${ELMASRY_VIP_URL:-https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX-ENGLISH-COLORS.zip}"
ZIP_FILE="$APP_DIR/tool.zip"
TOOL_DIR="$APP_DIR/PAK TOOL"

cleanup() {
    rm -rf "$APP_DIR"
}
trap cleanup EXIT

clear
printf '\033[96m%s\033[0m\n' 'ELMASRY VIP - Preparing...'

command -v pkg >/dev/null 2>&1 || {
    printf '\033[91m%s\033[0m\n' 'Error: This launcher must be run inside Termux.' >&2
    exit 1
}

pkg update -y
pkg install -y python unzip curl

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    -o "$ZIP_FILE" "$ZIP_URL"
unzip -oq "$ZIP_FILE" -d "$APP_DIR"
rm -f "$ZIP_FILE"

[ -d "$TOOL_DIR" ] || {
    printf '\033[91m%s\033[0m\n' 'Error: The "PAK TOOL" folder was not found.' >&2
    exit 1
}

# Working folders belong only in the phone storage root, not inside Termux.
for folder in ORIGINAL_PAK UNPACKED_FILES EDITTED_FILES EDIT_PAK REPACKED_PAK \
    FOUND_FILES Original_OBB unpacked_OBB Repacked_OBB LUA_ORIGINAL \
    DECOMPILED_LUA COMPILED_LUA LUA_REPORTS SM4_FINDER_SCAN PAK EDIT RESULT; do
    rm -rf "$TOOL_DIR/$folder"
done

cd "$TOOL_DIR"
bash install.sh
