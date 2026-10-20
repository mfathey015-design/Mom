#!/bin/bash

echo "===================================="
echo "   جارٍ تثبيت أداة ELMASRY VIP..."
echo "===================================="

# (اختياري) هنا تقدر تضيف خطوة طلب كود التفعيل الأول
# read -p "أدخل كود التفعيل الخاص بك: " activation_key
# لو الكود صح، كمل... لو غلط، اخرج من التثبيت.

# إنشاء مجلد مؤقت للتحميل
mkdir -p $HOME/.elmasry_temp
cd $HOME/.elmasry_temp

echo "[*] جارٍ تنزيل الملفات بأمان..."
# هنا بيتم تحميل الملف المشفر من المستودع الخاص بتاعك باستخدام الـ Token أو بطريقتك الآمنة
curl -sL -H "Authorization: token YOUR_GITHUB_TOKEN" -O https://raw.githubusercontent.com/mfathey015-design/TOM/main/ELMASRY-VIP-TERMUX.zip

echo "[*] جارٍ فك الضغط والتثبيت..."
unzip -o ELMASRY-VIP-TERMUX.zip -d $HOME/elmasry-tool

# تنظيف الملفات المؤقتة عشان ميبقاش فيه أي أثر
rm -rf $HOME/.elmasry_temp

echo "===================================="
echo "  تم التثبيت بنجاح! تشغيل الأداة..."
echo "===================================="

# تشغيل الأداة مباشرة
cd $HOME/elmasry-tool
python3 main.py
