#!/bin/bash

# Проверка входного параметра
if [ -z "$1" ]; then
    echo "Использование: $0 xxx.xxx.xxx.xxx/mm"
    exit 1
fi

NETWORK="$1"
SAFE_NET_NAME=$(echo "$NETWORK" | tr '/' '_')

NMAP_OUTPUT="nmap_scan_hostup_${SAFE_NET_NAME}.txt"
ENUM_DIR="enum4linux_scan_hostup_${SAFE_NET_NAME}"

mkdir -p "$ENUM_DIR"

echo "[*] Сканирование сети $NETWORK с помощью nmap..."

nmap -sn "$NETWORK" \
    | grep "Nmap scan report for" \
    | awk '{print $NF}' \
    > "$NMAP_OUTPUT"

echo "[*] Активные хосты сохранены в $NMAP_OUTPUT"

if [ ! -s "$NMAP_OUTPUT" ]; then
    echo "[!] Активные хосты не найдены"
    exit 0
fi

echo "[*] Запуск enum4linux-ng для каждого активного хоста..."

while read -r HOST_RAW; do
    HOST="${HOST_RAW//[\(\)]/}"

    echo "    [+] Обработка $HOST"
    enum4linux-ng -As "$HOST" > "${ENUM_DIR}/enum4linux_scan_hostup_${HOST}.txt"

done < "$NMAP_OUTPUT"

echo
echo "[*] Анализ открытых сервисов (389, 636, 445, 139)..."
echo "-----------------------------------------------"

FOUND=false

for FILE in "$ENUM_DIR"/enum4linux_scan_hostup_*.txt; do
    HOST=$(basename "$FILE" | sed 's/enum4linux_scan_hostup_//' | sed 's/\.txt//')

    # Проверяем наличие успешных подключений
    if grep -qE "\[\+\].*(389/tcp|636/tcp|445/tcp|139/tcp)" "$FILE"; then
        echo "[+] $HOST — обнаружены открытые сервисы:"
        grep -E "\[\+\].*(389/tcp|636/tcp|445/tcp|139/tcp)" "$FILE" \
            | sed 's/^/    /'
        FOUND=true
    fi
done

if [ "$FOUND" = false ]; then
    echo "[-] Хосты с открытыми портами 389, 636, 445, 139 не обнаружены"
fi

echo
echo "[✓] Скрипт завершён"
