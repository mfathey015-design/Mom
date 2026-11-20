#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ZIP_URL="https://raw.githubusercontent.com/mfathey015-design/Mom/main/LUA-TOOL-mfathey-VIP.zip"
APP_DIR="$HOME/LUA-TOOL-mfathey-VIP"
ARCHIVE="${TMPDIR:-$HOME}/lua-tool-install.zip"

if ! command -v pkg >/dev/null 2>&1; then
  echo "هذا الملف مخصص لـ Termux على Android."
  exit 1
fi

pkg install -y curl unzip python openssl-tool

if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 13) else 1)'; then
  echo "يتطلب هذا الإصدار Python 3.13. الإصدار المثبت حاليًا هو:"
  python3 --version || true
  echo "حدّث Python في Termux إلى 3.13 ثم أعد تشغيل الملف."
  exit 1
fi

mkdir -p "$HOME"
curl -fL --retry 3 "$ZIP_URL" -o "$ARCHIVE"
unzip -t "$ARCHIVE" >/dev/null
unzip -oq "$ARCHIVE" -d "$HOME"
rm -f "$ARCHIVE"

if [ ! -f "$APP_DIR/run_merged.sh" ]; then
  echo "لم أجد run_merged.sh داخل الأرشيف بعد فك الضغط."
  exit 1
fi

chmod +x "$APP_DIR/run_merged.sh"
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/lua-tool" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/sh
APP_DIR="$HOME/LUA-TOOL-mfathey-VIP"
if [ ! -f "$APP_DIR/run_merged.sh" ]; then
  echo "ملفات الأداة غير موجودة. أعد تشغيل ملف التثبيت من GitHub."
  exit 1
fi
exec sh "$APP_DIR/run_merged.sh" "$@"
LAUNCHER
chmod +x "$PREFIX/bin/lua-tool"

echo "تم التثبيت. سيبدأ تشغيل الأداة الآن."
echo "للتشغيل لاحقًا، اكتب: lua-tool"
exec "$PREFIX/bin/lua-tool"
