#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_DIR="$HOME/elmasry-tool"
ZIP_URL="https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX.zip"

# Start with a clean terminal and show the tool banner at the top.
clear
printf '\033[96m%s\033[0m\n' '╔════════════════════════════════════════════╗'
printf '\033[95m%s\033[0m\n' '║            ELMASRY VIP - TOOL              ║'
printf '\033[94m%s\033[0m\n' '╚════════════════════════════════════════════╝'
printf '\033[93m%s\033[0m\n\n' 'Preparing the tool. Please wait...'

pkg update -y
pkg install python unzip curl -y

printf '\033[96m%s\033[0m\n' 'Downloading tool files...'
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
curl -fL --retry 3 --retry-delay 2 -o "$APP_DIR/tool.zip" "$ZIP_URL"
unzip -oq "$APP_DIR/tool.zip" -d "$APP_DIR"
rm -f "$APP_DIR/tool.zip"

TOOL_DIR="$APP_DIR/PAK TOOL"
if [ ! -d "$TOOL_DIR" ]; then
    printf '\033[91m%s\033[0m\n' 'Error: The "PAK TOOL" folder was not found in the downloaded archive.'
    exit 1
fi

cd "$TOOL_DIR"

# Do not upgrade pip in Termux. Install only the tool's declared dependencies.
if [ -f requirements.txt ]; then
    printf '\033[94m%s\033[0m\n' 'Installing required Python packages...'
    python -m pip install -r requirements.txt
fi

# Clear setup/download output so the application interface starts at the top.
clear
printf '\033[96m%s\033[0m\n' '╔════════════════════════════════════════════╗'
printf '\033[95m%s\033[0m\n' '║            ELMASRY VIP - TOOL              ║'
printf '\033[94m%s\033[0m\n' '╚════════════════════════════════════════════╝'
printf '\n'

if [ -f run.sh ]; then
    exec bash run.sh
elif [ -f obb_pak_tool.py ]; then
    exec python obb_pak_tool.py
else
    printf '\033[91m%s\033[0m\n' 'Error: Neither run.sh nor obb_pak_tool.py was found.'
    exit 1
fi
