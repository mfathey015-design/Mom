#!/bin/bash
pkg update -y && pkg install python unzip curl -y
rm -rf $HOME/elmasry-tool
mkdir -p $HOME/elmasry-tool
cd $HOME/elmasry-tool
curl -L -o tool.zip "https://raw.githubusercontent.com/mfathey015-design/Mom/main/ELMASRY-VIP-TERMUX.zip"
unzip -o tool.zip
rm -f tool.zip

# الدخول داخل مجلد الأداة وتشغيل السكريپت الأساسي الذي يتعامل مع payload.enc
cd "PAK TOOL"
if [ -f "run.sh" ]; then
    bash run.sh
else
    python3 obb_pak_tool.py
fi
