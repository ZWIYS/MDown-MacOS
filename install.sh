#!/bin/bash
# Собирает приложение и ставит его в /Applications (иконка и имя «MDown» появятся в Launchpad и Доке).
set -e
cd "$(dirname "$0")"
./build.sh
pkill -x MDown 2>/dev/null || true
pkill -x MDReader 2>/dev/null || true
rm -rf "/Applications/MD Reader.app" "/Applications/MDown.app"   # старое имя тоже убираем
cp -R MDown.app "/Applications/MDown.app"
touch "/Applications/MDown.app"
echo "Установлено: /Applications/MDown.app"
