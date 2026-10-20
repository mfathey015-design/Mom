#!/bin/bash

echo "===================================="
echo "   جارٍ تثبيت أداة ELMASRY VIP..."
echo "===================================="

# 1. إنشاء مجلد مؤقت للتحميل
mkdir -p $HOME/.my_tool_temp
cd $HOME/.my_tool_temp

echo "[*] جارٍ تنزيل الملفات بأمان..."
# 2. تحميل الملف المضغوط بالرابط المباشر الصحيح من المستودع العام Mom
curl -sL -o ELMASRY-VIP-TERMUX.zip "https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX.zip"

echo "[*] جارٍ فك الضغط والتثبيت..."
# 3. إنشاء مجلد الأداة وفك الملفات بداخله
mkdir -p $HOME/elmasry-tool
unzip -o ELMASRY-VIP-TERMUX.zip -d $HOME/elmasry-tool

# 4. تنظيف الملفات المؤقتة
rm -rf $HOME/.my_tool_temp

echo "===================================="
echo "  تم التثبيت بنجاح! تشغيل الأداة..."
echo "===================================="

# 5. الدخول لمجلد الأداة وتشغيلها
cd $HOME/elmasry-tool
python3 main.py
