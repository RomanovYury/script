#!/bin/bash

# === Заголовок и информация о скрипте ===
echo "==========================================="
echo " АНАЛИЗ ПАРОЛЬНОЙ ПОЛИТИКИ (Kali Linux)"
echo "==========================================="
echo "Дата и время: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# === 1. Проверка файла /etc/login.defs ===
echo "1. ОСНОВНЫЕ ПАРАМЕТРЫ ИЗ /etc/login.defs:"
if [ -f /etc/login.defs ]; then
    grep -E "^PASS_MAX_DAYS|^PASS_MIN_DAYS|^PASS_WARN_AGE|^PASS_MIN_LEN|^UID_MIN|^GID_MIN" /etc/login.defs | while read -r line; do
        echo "  $line"
    done
else
    echo "  Файл /etc/login.defs не найден!"
fi
echo

# === 2. Проверка файла /etc/security/pwquality.conf ===
echo "2. ПРАВИЛА СЛОЖНОСТИ ПАРОЛЕЙ (/etc/security/pwquality.conf):"
if [ -f /etc/security/pwquality.conf ]; then
    grep -v "^#" /etc/security/pwquality.conf | grep -v "^$" | while read -r line; do
        echo "  $line"
    done
else
    echo "  Файл /etc/security/pwquality.conf не найден (возможно, не установлен пакет libpam-pwquality)."
fi
echo

# === 3. Проверка настроек PAM (/etc/pam.d/common-password) ===
echo "3. НАСТРОЙКИ PAM (/etc/pam.d/common-password):"
if [ -f /etc/pam.d/common-password ]; then
    grep -i "password" /etc/pam.d/common-password | grep -v "^#" | while read -r line; do
        echo "  $line"
    done
else
    echo "  Файл /etc/pam.d/common-password не найден!"
fi
echo

# === 4. Проверка сроков действия паролей для всех пользователей ===
echo "4. СРОКИ ДЕЙСТВИЯ ПАРОЛЕЙ ПОЛЬЗОВАТЕЛЕЙ:"
echo "  Пользователь           | Статус           | Последний смен | Макс. дней | Мин. дней | Предупреждение"
echo "  ---------------------+------------------+--------------+-----------+-----------+------------"

while IFS=: read -r user pass uid gid full home shell; do
    # Пропускаем системные аккаунты (UID < 1000)
    if [ "$uid" -lt 1000 ]; then
        continue
    fi

    # Получаем информацию о пароле
    chage_info=$(sudo chage -l "$user" 2>/dev/null)
    last_change=$(echo "$chage_info" | grep "Last password change" | awk -F': ' '{print $2}')
    max_days=$(echo "$chage_info" | grep "Maximum number of days" | awk -F': ' '{print $2}')
    min_days=$(echo "$chage_info" | grep "Minimum number of days" | awk -F': ' '{print $2}')
    warn_days=$(echo "$chage_info" | grep "Number of days warning" | awk -F': ' '{print $2}')

    # Определяем статус
    if echo "$last_change" | grep -q "never"; then
        status="Никогда не менялся"
    elif echo "$last_change" | grep -q "password expired"; then
        status="Устарел"
    else
        status="Активен"
    fi

    printf "  %-20s | %-16s | %-12s | %-10s | %-10s | %s\n" \
        "$user" "$status" "$last_change" "$max_days" "$min_days" "$warn_days"
done < /etc/passwd
echo

# === 5. Проверка наличия MFA/OTP-решений ===
echo "5. НАЛИЧИЕ MFA/OTP-РЕШЕНИЙ:"
mfa_found=false

# Google Authenticator
if dpkg -l | grep -q google-authenticator; then
    echo "  • Google Authenticator: установлен"
    mfa_found=true
fi

# SSH + MFA
ssh_mfa=$(grep -i "challenge" /etc/ssh/sshd_config 2>/dev/null | grep -v "^#")
if [ -n "$ssh_mfa" ]; then
    echo "  • SSH MFA: включён ($ssh_mfa)"
    mfa_found=true
fi

# PAM + OTP
pam_otp=$(grep -i "otp" /etc/pam.d/* 2>/dev/null | head -n 1)
if [ -n "$pam_otp" ]; then
    echo "  • PAM OTP: настроен ($pam_otp)"
    mfa_found=true
fi

if ! $mfa_found; then
    echo "  • MFA/OTP не обнаружено"
fi
echo

# === 6. Итоговый вывод ===
echo "6. ИТОГИ:"
echo "  - Файл /etc/login.defs: $( [ -f /etc/login.defs ] && echo "найден" || echo "отсутствует" )"
echo "  - pwquality.conf: $( [ -f /etc/security/pwquality.conf ] && echo "настроен" || echo "не настроен" )"
echo "  - PAM: $( grep -q "pam_unix" /etc/pam.d/common-password 2>/dev/null && echo "активен" || echo "не настроен" )"
echo "  - MFA/OTP: $( $mfa_found && echo "обнаружено" || echo "не обнаружено" )"

echo

echo "Анализ завершён."
