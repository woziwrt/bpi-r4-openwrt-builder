#!/bin/bash

SRC_DIR="/mnt/data/openwrt/bpi-r4-openwrt-builder/openwrt/bin/"
DST_DIR="/opt/nginx/html/openwrt/"
REMOTE_HOST="192.168.*.*"
REMOTE_USER="*"
REMOTE_PASS="*"

echo "====================================================="
echo " 🔧 Синхронизация OpenWrt сборки"
echo " Источник: $SRC_DIR"
echo " Назначение: $REMOTE_USER@$REMOTE_HOST:$DST_DIR"
echo "====================================================="
echo

echo "[1/4] Проверяем наличие каталога на удалённом сервере..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no \
    "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $DST_DIR"
echo " ✔ Каталог существует или создан."
echo

echo "[2/4] Запуск rsync с прогрессом..."
sshpass -p "$REMOTE_PASS" rsync -avz --delete --progress \
    -e "ssh -o StrictHostKeyChecking=no" \
    "$SRC_DIR" "$REMOTE_USER@$REMOTE_HOST:$DST_DIR"

if [ $? -ne 0 ]; then
    echo " ❌ Ошибка: rsync завершился с ошибкой."
    exit 1
fi
echo " ✔ Файлы успешно синхронизированы."
echo

echo "[3/4] Установка прав 777..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no \
    "$REMOTE_USER@$REMOTE_HOST" "chmod -R 777 $DST_DIR"
echo " ✔ Права установлены."
echo

echo "[4/4] Готово!"
echo "====================================================="
echo " 🎉 Синхронизация завершена без ошибок."
echo "====================================================="