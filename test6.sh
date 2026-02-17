#!/bin/bash

# Скрипт для сбора информации о парольных политиках и MFA в FreeIPA
# Автор: Assistant
# Дата: 2024

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для проверки выполнения команд
check_command() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при выполнении команды: $1${NC}"
        return 1
    fi
}

# Функция для вывода разделителя
print_separator() {
    echo -e "${BLUE}==================================================${NC}"
}

# Проверка наличия kinit и прав администратора
echo -e "${YELLOW}Проверка аутентификации в FreeIPA...${NC}"
if ! klist -s 2>/dev/null; then
    echo -e "${RED}Нет активного билета Kerberos. Выполните kinit admin${NC}"
    exit 1
fi

# Создание временного файла для отчета
REPORT_FILE="/tmp/ipa_password_mfa_report_$(date +%Y%m%d_%H%M%S).txt"
echo "Отчет по парольным политикам и MFA в FreeIPA" > $REPORT_FILE
echo "Дата создания: $(date)" >> $REPORT_FILE
echo "===========================================" >> $REPORT_FILE

print_separator
echo -e "${GREEN}СБОР ИНФОРМАЦИИ О ПАРОЛЬНЫХ ПОЛИТИКАХ И MFA В FREEIPA${NC}"
print_separator

# 1. Информация о глобальной конфигурации паролей
echo -e "\n${YELLOW}1. Глобальная конфигурация паролей:${NC}"
echo -e "\n1. Глобальная конфигурация паролей:" >> $REPORT_FILE

PW_POLICY=$(ipa pwpolicy-show 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$PW_POLICY"
    echo "$PW_POLICY" >> $REPORT_FILE
else
    echo -e "${RED}Не удалось получить глобальную политику паролей${NC}"
    echo "Не удалось получить глобальную политику паролей" >> $REPORT_FILE
fi

# 2. Список всех групп и их политик паролей
echo -e "\n${YELLOW}2. Политики паролей для групп:${NC}"
echo -e "\n2. Политики паролей для групп:" >> $REPORT_FILE

GROUPS=$(ipa group-find --pkey-only --timelimit=5 2>/dev/null | grep "Group name:" | awk '{print $3}')
if [ -n "$GROUPS" ]; then
    for GROUP in $GROUPS; do
        echo -e "${BLUE}Группа: $GROUP${NC}"
        echo "Группа: $GROUP" >> $REPORT_FILE
        GROUP_POLICY=$(ipa pwpolicy-show "$GROUP" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$GROUP_POLICY"
            echo "$GROUP_POLICY" >> $REPORT_FILE
        else
            echo -e "${YELLOW}  Нет специфической политики для группы${NC}"
            echo "  Нет специфической политики для группы" >> $REPORT_FILE
        fi
        echo "---" >> $REPORT_FILE
    done
else
    echo -e "${RED}Не удалось получить список групп${NC}"
fi

# 3. Информация о настройках MFA (OTP)
echo -e "\n${YELLOW}3. Настройки многофакторной аутентификации (OTP):${NC}"
echo -e "\n3. Настройки многофакторной аутентификации (OTP):" >> $REPORT_FILE

# Проверка наличия OTP токенов
OTP_TOKENS=$(ipa otptoken-find --all --raw 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$OTP_TOKENS" ]; then
    echo -e "${GREEN}Найдены OTP токены:${NC}"
    echo "Найдены OTP токены:" >> $REPORT_FILE
    
    # Подсчет количества токенов
    TOKEN_COUNT=$(echo "$OTP_TOKENS" | grep -c "dn:" || echo "0")
    echo -e "  Всего токенов: $TOKEN_COUNT"
    echo "  Всего токенов: $TOKEN_COUNT" >> $REPORT_FILE
    
    # Детальная информация о токенах
    echo "$OTP_TOKENS" | while IFS= read -r line; do
        if [[ $line == *"dn:"* ]]; then
            echo -e "${BLUE}  $line${NC}"
            echo "  $line" >> $REPORT_FILE
        elif [[ $line == *"ipatokenowner:"* ]]; then
            echo -e "    Владелец: ${GREEN}$(echo $line | awk '{print $2}')${NC}"
            echo "    $line" >> $REPORT_FILE
        elif [[ $line == *"ipatokenotpalgorithm:"* ]]; then
            echo -e "    Алгоритм: ${YELLOW}$(echo $line | awk '{print $2}')${NC}"
            echo "    $line" >> $REPORT_FILE
        fi
    done
else
    echo -e "${YELLOW}OTP токены не найдены или не настроены${NC}"
    echo "OTP токены не найдены или не настроены" >> $REPORT_FILE
fi

# 4. Информация о RADIUS серверах (если используется)
echo -e "\n${YELLOW}4. Настройки RADIUS (если используется):${NC}"
echo -e "\n4. Настройки RADIUS (если используется):" >> $REPORT_FILE

RADIUS_SERVERS=$(ipa radiusproxy-find 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$RADIUS_SERVERS" ] && [[ ! "$RADIUS_SERVERS" == *"0 matches"* ]]; then
    echo -e "${GREEN}Найдены RADIUS прокси:${NC}"
    echo "Найдены RADIUS прокси:" >> $REPORT_FILE
    echo "$RADIUS_SERVERS"
    echo "$RADIUS_SERVERS" >> $REPORT_FILE
else
    echo -e "${YELLOW}RADIUS прокси не настроены${NC}"
    echo "RADIUS прокси не настроены" >> $REPORT_FILE
fi

# 5. Информация о пользователях с MFA
echo -e "\n${YELLOW}5. Пользователи с настроенной двухфакторной аутентификацией:${NC}"
echo -e "\n5. Пользователи с настроенной двухфакторной аутентификацией:" >> $REPORT_FILE

# Поиск пользователей с OTP токенами
echo -e "${BLUE}Пользователи с OTP токенами:${NC}"
echo "Пользователи с OTP токенами:" >> $REPORT_FILE
USERS_WITH_OTP=$(ipa user-find --all --raw 2>/dev/null | grep -B 5 "ipatokenuniqueid" | grep "User login:" | awk '{print $3}' | sort -u)
if [ -n "$USERS_WITH_OTP" ]; then
    for USER in $USERS_WITH_OTP; do
        echo -e "  ${GREEN}$USER${NC}"
        echo "  $USER" >> $REPORT_FILE
    done
else
    echo -e "  ${YELLOW}Нет пользователей с OTP токенами${NC}"
    echo "  Нет пользователей с OTP токенами" >> $REPORT_FILE
fi

# 6. Проверка настроек аутентификации для сервисов
echo -e "\n${YELLOW}6. Настройки аутентификации для сервисов:${NC}"
echo -e "\n6. Настройки аутентификации для сервисов:" >> $REPORT_FILE

SERVICES=$(ipa service-find --pkey-only 2>/dev/null | grep "Principal name:" | head -5 | awk '{print $3}')
if [ -n "$SERVICES" ]; then
    echo -e "${BLUE}Первые 5 сервисов:${NC}"
    echo "Первые 5 сервисов:" >> $REPORT_FILE
    for SERVICE in $SERVICES; do
        SERVICE_AUTH=$(ipa service-show "$SERVICE" --all --raw 2>/dev/null | grep -E "Requires pre-authentication|Authentication Indicators")
        if [ -n "$SERVICE_AUTH" ]; then
            echo -e "  ${GREEN}$SERVICE${NC}"
            echo "  $SERVICE" >> $REPORT_FILE
            echo "$SERVICE_AUTH" | while IFS= read -r line; do
                echo -e "    $line"
                echo "    $line" >> $REPORT_FILE
            done
        fi
    done
fi

# 7. Информация о Kerberos тикетах и настройках
echo -e "\n${YELLOW}7. Информация о Kerberos настройках:${NC}"
echo -e "\n7. Информация о Kerberos настройках:" >> $REPORT_FILE

# Проверка наличия PKINIT
echo -e "${BLUE}Проверка PKINIT (смарт-карты):${NC}"
echo "Проверка PKINIT (смарт-карты):" >> $REPORT_FILE
PKINIT_STATUS=$(ipa-pkinit-status 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PKINIT настроен${NC}"
    echo "PKINIT настроен" >> $REPORT_FILE
else
    echo -e "${YELLOW}PKINIT не настроен или не доступен${NC}"
    echo "PKINIT не настроен или не доступен" >> $REPORT_FILE
fi

# 8. Сводная информация о политиках
print_separator
echo -e "${GREEN}СВОДНАЯ ИНФОРМАЦИЯ:${NC}"
print_separator

echo -e "\n${BLUE}Краткое резюме:${NC}"
echo -e "\nКраткое резюме:" >> $REPORT_FILE

# Подсчет статистики
TOTAL_USERS=$(ipa user-find --pkey-only --timelimit=5 2>/dev/null | grep -c "User login:" || echo "0")
TOTAL_GROUPS=$(ipa group-find --pkey-only --timelimit=5 2>/dev/null | grep -c "Group name:" || echo "0")
TOTAL_OTP_TOKENS=$(ipa otptoken-find 2>/dev/null | grep -c "Unique ID:" || echo "0")

echo -e "  Всего пользователей: ${GREEN}$TOTAL_USERS${NC}"
echo -e "  Всего групп: ${GREEN}$TOTAL_GROUPS${NC}"
echo -e "  Всего OTP токенов: ${GREEN}$TOTAL_OTP_TOKENS${NC}"
echo -e "  Пользователей с MFA: ${GREEN}$(echo "$USERS_WITH_OTP" | wc -w)${NC}"

echo "  Всего пользователей: $TOTAL_USERS" >> $REPORT_FILE
echo "  Всего групп: $TOTAL_GROUPS" >> $REPORT_FILE
echo "  Всего OTP токенов: $TOTAL_OTP_TOKENS" >> $REPORT_FILE
echo "  Пользователей с MFA: $(echo "$USERS_WITH_OTP" | wc -w)" >> $REPORT_FILE

print_separator
echo -e "${GREEN}Отчет сохранен в: $REPORT_FILE${NC}"
echo -e "${YELLOW}Для просмотра отчета: cat $REPORT_FILE${NC}"
print_separator

# Опционально: создание HTML отчета
if command -v ansi2html &> /dev/null; then
    HTML_REPORT="${REPORT_FILE%.txt}.html"
    cat $REPORT_FILE | ansi2html > $HTML_REPORT
    echo -e "${GREEN}HTML отчет создан: $HTML_REPORT${NC}"
fi

# Проверка безопасности
echo -e "\n${YELLOW}ПРОВЕРКА БЕЗОПАСНОСТИ:${NC}"
echo -e "\nПРОВЕРКА БЕЗОПАСНОСТИ:" >> $REPORT_FILE

# Проверка минимальной длины пароля
MIN_PW_LENGTH=$(ipa pwpolicy-show 2>/dev/null | grep "Min length:" | awk '{print $3}')
if [ -n "$MIN_PW_LENGTH" ] && [ "$MIN_PW_LENGTH" -lt 8 ]; then
    echo -e "${RED}  ВНИМАНИЕ: Минимальная длина пароля ($MIN_PW_LENGTH) меньше рекомендуемой (8)${NC}"
    echo "  ВНИМАНИЕ: Минимальная длина пароля ($MIN_PW_LENGTH) меньше рекомендуемой (8)" >> $REPORT_FILE
fi

# Проверка использования MFA
if [ "$TOTAL_OTP_TOKENS" -eq 0 ]; then
    echo -e "${YELLOW}  ВНИМАНИЕ: MFA не используется${NC}"
    echo "  ВНИМАНИЕ: MFA не используется" >> $REPORT_FILE
fi

echo -e "\n${GREEN}Скрипт завершил работу${NC}"
