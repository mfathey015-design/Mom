#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_DIR="$HOME/elmasry-tool"
ZIP_URL="https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX.zip"

printf '\033[96m%s\033[0m\n' '[1/4] Updating Termux packages...'
pkg update -y
pkg install python unzip curl -y

printf '\033[93m%s\033[0m\n' '[2/4] Downloading the tool...'
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
curl -fL --retry 3 --retry-delay 2 -o "$APP_DIR/tool.zip" "$ZIP_URL"

printf '\033[95m%s\033[0m\n' '[3/4] Extracting files...'
unzip -oq "$APP_DIR/tool.zip" -d "$APP_DIR"
rm -f "$APP_DIR/tool.zip"

TOOL_DIR="$APP_DIR/PAK TOOL"
if [ ! -d "$TOOL_DIR" ]; then
    printf '\033[91m%s\033[0m\n' 'Error: The "PAK TOOL" folder was not found in the downloaded archive.'
    exit 1
fi

cd "$TOOL_DIR"
if [ -f requirements.txt ]; then
    printf '\033[94m%s\033[0m\n' '[4/4] Installing Python requirements...'
    python -m pip install -r requirements.txt
fi

if [ -f run.sh ]; then
    exec bash run.sh
elif [ -f obb_pak_tool.py ]; then
    exec python obb_pak_tool.py
else
    printf '\033[91m%s\033[0m\n' 'Error: Neither run.sh nor obb_pak_tool.py was found.'
    exit 1
fi
