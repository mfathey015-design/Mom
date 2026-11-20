#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ZIP_URL="https://raw.githubusercontent.com/mfathey015-design/Mom/main/LUA-TOOL-mfathey-VIP.zip"
APP_DIR="$HOME/LUA-TOOL-mfathey-VIP"
ARCHIVE="${TMPDIR:-$HOME}/lua-tool-install.zip"

if ! command -v pkg >/dev/null 2>&1; then
  printf 'This installer is for Termux on Android.\n' >&2
  exit 1
fi

if ! pkg install -y curl unzip python openssl-tool >/dev/null 2>&1; then
  printf 'Unable to install required packages.\n' >&2
  exit 1
fi

if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 13) else 1)'; then
  printf 'Python 3.13 is required. Installed version: ' >&2
  python3 --version >&2 || true
  exit 1
fi

mkdir -p "$HOME"
curl -fsSL --retry 3 "$ZIP_URL" -o "$ARCHIVE"
unzip -t "$ARCHIVE" >/dev/null
unzip -oq "$ARCHIVE" -d "$HOME"
rm -f "$ARCHIVE"

if [ ! -f "$APP_DIR/run_merged.sh" ]; then
  printf 'run_merged.sh was not found in the downloaded archive.\n' >&2
  exit 1
fi

chmod +x "$APP_DIR/run_merged.sh"
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/lua-tool" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/sh
APP_DIR="$HOME/LUA-TOOL-mfathey-VIP"
if [ ! -f "$APP_DIR/run_merged.sh" ]; then
  echo "Tool files are missing. Run the GitHub installer again."
  exit 1
fi
printf '\033[2J\033[3J\033[H'
exec sh "$APP_DIR/run_merged.sh" "$@"
LAUNCHER
chmod +x "$PREFIX/bin/lua-tool"
exec "$PREFIX/bin/lua-tool"
