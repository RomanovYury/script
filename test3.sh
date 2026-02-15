#!/bin/bash

# Скрипт для сбора информации о пользователе и его группах в FreeIPA

# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 <имя_пользователя>"
    echo "Пример: $0 ivanov"
    exit 1
fi

USERNAME="$1"

# Проверка аутентификации в FreeIPA
if ! klist -s 2>/dev/null; then
    echo "Требуется аутентификация в FreeIPA"
    echo -n "Введите пароль администратора: "
    read -s ADMIN_PASS
    echo
    
    echo "$ADMIN_PASS" | kinit admin 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Ошибка аутентификации"
        exit 1
    fi
fi

# Получение информации о пользователе
echo "========================================="
echo "ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЕ: $USERNAME"
echo "========================================="

# Основная информация о пользователе
USER_INFO=$(ipa user-show "$USERNAME" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Ошибка: Пользователь $USERNAME не найден"
    exit 1
fi

# Вывод основной информации
echo "$USER_INFO" | grep -E "User login:|First name:|Last name:|Full name:|Email:|Home directory:|Login shell:|UID:|GID:|Account disabled:" | sed 's/^[[:space:]]*//'

echo -e "\n========================================="
echo "ГРУППЫ ПОЛЬЗОВАТЕЛЯ:"
echo "========================================="

# Получение списка групп (только прямые членства)
echo "Прямые группы:"
ipa user-show "$USERNAME" | grep "Member of groups:" | sed 's/Member of groups://' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v "^$" | while read group; do
    if [ ! -z "$group" ]; then
        echo "  → $group"
    fi
done

# Получение косвенных групп (через другие группы)
echo -e "\nКосвенные группы:"
ipa user-show "$USERNAME" | grep "Indirect Member" | sed 's/Indirect Member of groups://' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v "^$" | while read group; do
    if [ ! -z "$group" ]; then
        echo "  → $group"
    fi
done

# Подсчет общего количества групп
echo -e "\n========================================="
TOTAL_GROUPS=$(ipa user-show "$USERNAME" | grep -E "Member of groups:|Indirect Member" | tr ',' '\n' | grep -v "^$" | grep -v "Member of groups:" | grep -v "Indirect Member" | wc -l)
echo "Всего групп: $TOTAL_GROUPS"
echo "========================================="

# Получение информации о группах (описание каждой группы)
echo -e "\nДЕТАЛЬНАЯ ИНФОРМАЦИЯ О ГРУППАХ:"
echo "========================================="

# Получаем все группы пользователя
ALL_GROUPS=$(ipa user-show "$USERNAME" | grep -E "Member of groups:|Indirect Member" | sed 's/Member of groups://' | sed 's/Indirect Member of groups://' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v "^$")

for group in $ALL_GROUPS; do
    echo -e "\n--- Группа: $group ---"
    ipa group-show "$group" 2>/dev/null | grep -E "Group name:|Description:|GID:" | sed 's/^[[:space:]]*//'
done

echo -e "\n========================================="
