#!/bin/bash

# Скрипт для вывода всех пользователей и их групп в табличном виде

# Проверка аутентификации
if ! klist -s 2>/dev/null; then
    echo "Ошибка: нет активной сессии FreeIPA"
    echo "Выполните: kinit admin"
    exit 1
fi

# Получаем список всех пользователей
USERS=$(ipa user-find --pkey-only --raw 2>/dev/null | grep "uid:" | awk '{print $2}' | sort)

if [ -z "$USERS" ]; then
    echo "Пользователи не найдены"
    exit 1
fi

# Заголовок таблицы
printf "%-20s | %-25s | %-30s | %-15s\n" "ЛОГИН" "ИМЯ И ФАМИЛИЯ" "ГРУППЫ" "ВСЕГО ГРУПП"
printf "%s\n" "────────────────────────────────────────────────────────────────────────────────────────────────────"

# Проходим по каждому пользователю
echo "$USERS" | while read username; do
    if [ ! -z "$username" ]; then
        # Получаем имя и фамилию
        FULLNAME=$(ipa user-show "$username" 2>/dev/null | grep "Full name:" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        
        # Получаем группы (только прямые, для краткости)
        GROUPS=$(ipa user-show "$username" 2>/dev/null | grep "Member of groups:" | sed 's/Member of groups://' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v "^$" | head -3 | tr '\n' ',' | sed 's/,$//')
        
        # Если групп больше 3, добавляем многоточие
        GROUP_COUNT=$(ipa user-show "$username" 2>/dev/null | grep "Member of groups:" | tr ',' '\n' | grep -v "^$" | wc -l)
        
        if [ $GROUP_COUNT -gt 3 ]; then
            GROUPS="$GROUPS..."
        fi
        
        if [ -z "$GROUPS" ]; then
            GROUPS="нет групп"
        fi
        
        # Если нет полного имени, используем логин
        if [ -z "$FULLNAME" ]; then
            FULLNAME="<не указано>"
        fi
        
        # Выводим строку таблицы
        printf "%-20s | %-25s | %-30s | %-15s\n" "$username" "${FULLNAME:0:25}" "${GROUPS:0:30}" "$GROUP_COUNT"
    fi
done

printf "%s\n" "────────────────────────────────────────────────────────────────────────────────────────────────────"
