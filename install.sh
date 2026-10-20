#!/bin/bash
pkg update -y && pkg install python unzip curl -y
rm -rf $HOME/elmasry-tool
mkdir -p $HOME/elmasry-tool
cd $HOME/elmasry-tool
curl -L -o tool.zip "https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX.zip"
unzip -o tool.zip
rm -f tool.zip
# الدخول للمجلد اللي بينتج بعد فك الضغط وتشغيل ملف التشغيل الأساسي
cd "PAK TOOL"
bash run.sh
