#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_DIR="$HOME/elmasry-tool"
ZIP_URL="https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX.zip"

clear
printf '\033[96m%s\033[0m\n' 'ELMASRY VIP - Preparing...'
pkg update -y
pkg install python unzip curl -y

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
curl -fL --retry 3 --retry-delay 2 -o "$APP_DIR/tool.zip" "$ZIP_URL"
unzip -oq "$APP_DIR/tool.zip" -d "$APP_DIR"
rm -f "$APP_DIR/tool.zip"

TOOL_DIR="$APP_DIR/PAK TOOL"
if [ ! -d "$TOOL_DIR" ]; then
    printf '\033[91m%s\033[0m\n' 'Error: The "PAK TOOL" folder was not found in the GitHub archive.'
    exit 1
fi
cd "$TOOL_DIR"

if [ -f requirements.txt ]; then
    python -m pip install -r requirements.txt
fi

# Localize the downloaded GitHub source without changing the repository itself.
python - <<'PY'
from pathlib import Path
p = Path("obb_pak_tool.py")
s = p.read_text(encoding="utf-8")

# English key-entry prompt in yellow, not the terminal's default white.
s = s.replace('key = input("\\n🔑 أدخل مفتاح الاشتراك: ").strip()',
              'print("\\033[93m\\nEnter your subscription key: \\033[0m", end="", flush=True)\\n        key = input().strip()')
s = s.replace('key = input("\\nEnter your subscription key: ").strip()',
              'print("\\033[93m\\nEnter your subscription key: \\033[0m", end="", flush=True)\\n        key = input().strip()')

# Hide connection status completely (network validation still occurs).
s = s.replace('print("\\n🌐 جاري الاتصال بسيرفر التراخيص...")',
              '# Connection status hidden; license validation continues below.')
s = s.replace('print("\\nConnecting to the license server...")',
              '# Connection status hidden; license validation continues below.')

# Colored English title, shown by the tool at the top after the launcher clears the screen.
s = s.replace('''    print("╔════════════════════════════════════════════╗")
    print("║       ELMASRY VIP - License Check          ║")
    print("╚════════════════════════════════════════════╝")''', '''    print("\\033[96m╔════════════════════════════════════════════╗\\033[0m")
    print("\\033[95m║       ELMASRY VIP - License Check          ║\\033[0m")
    print("\\033[94m╚════════════════════════════════════════════╝\\033[0m")''')

# English-only errors and help text.
s = s.replace('print(f"\\n✖ {message}")', 'print(f"\\n\\033[91m[ERROR] {message}\\033[0m")')
s = s.replace('print("للاشتراك أو الدعم تواصل مع المطور: @mfathey466")',
              'print("For subscription or support, contact: @mfathey466")')
s = s.replace('print(f"رابط تيليجرام: {DEVELOPER_URL}\\n")',
              'print(f"Telegram: {DEVELOPER_URL}\\n")')
s = s.replace('"لم يتم إدخال مفتاح اشتراك."', '"No subscription key was entered."')
s = s.replace('"تعذر الاتصال بسيرفر التراخيص. تحقق من الإنترنت وحاول مرة أخرى."',
              '"Could not connect to the license server. Check your internet and try again."')
s = s.replace('"المفتاح غير صحيح أو غير مفعل."', '"The key is invalid or inactive."')
s = s.replace('"بيانات انتهاء الاشتراك غير صالحة."', '"The subscription expiry date is invalid."')
s = s.replace('f"انتهى الاشتراك بتاريخ {expiry}."', 'f"The subscription expired on {expiry}."')
s = s.replace('print(f"التفاصيل: {exc}")', 'print(f"Details: {exc}")')
s = s.replace('print("\\n✅ تم التحقق من المفتاح بنجاح.")',
              'print("\\n\\033[92mSubscription key verified successfully.\\033[0m")')
# Do not show server-provided text: it may contain Arabic. Show a clean English expiry line.
s = s.replace('print(record.get("message") or f"الاشتراك صالح حتى {expiry}")',
              'print(f"Subscription is valid until {expiry}")')
s = s.replace('print(record.get("message") or f"Subscription is valid until {expiry}")',
              'print(f"Subscription is valid until {expiry}")')
p.write_text(s, encoding="utf-8")
PY

clear
if [ -f run.sh ]; then
    exec bash run.sh
elif [ -f obb_pak_tool.py ]; then
    exec python obb_pak_tool.py
else
    printf '\033[91m%s\033[0m\n' 'Error: Neither run.sh nor obb_pak_tool.py was found.'
    exit 1
fi
