#!/bin/bash

# Цвета для оформления вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Функция для вывода разделителя
print_separator() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════${NC}"
}

# Функция для вывода заголовка
print_header() {
    local text="$1"
    local width=70
    local padding=$(( (width - ${#text}) / 2 ))
    
    print_separator
    printf "${YELLOW}%*s%s%*s${NC}\n" $padding "" "$text" $padding ""
    print_separator
}

# Функция для вывода информации о пользователе с группами
print_user_info() {
    local username="$1"
    
    # Получаем информацию о пользователе
    local user_info=$(ipa user-show "$username" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Пользователь $username не найден${NC}"
        return 1
    fi
    
    # Получаем группы пользователя
    local user_groups=$(ipa user-show "$username" --all | grep -E "Member of groups|Indirect Member" | sed 's/^[[:space:]]*//')
    
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE} Информация о пользователе: ${GREEN}$username${WHITE}${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"
    
    # Выводим основную информацию
    echo "$user_info" | while IFS= read -r line; do
        if [[ ! "$line" =~ "Member of groups" ]] && [[ ! "$line" =~ "Indirect Member" ]]; then
            if [[ ! -z "$line" ]]; then
                printf "${CYAN}│${NC} %-50s ${CYAN}│${NC}\n" "$line"
            fi
        fi
    done
    
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${YELLOW} Группы пользователя:${NC}"
    
    # Выводим группы
    if [ -z "$user_groups" ]; then
        printf "${CYAN}│${NC} ${RED}Пользователь не состоит в группах${NC}\n"
    else
        echo "$user_groups" | while IFS= read -r group_line; do
            if [[ ! -z "$group_line" ]]; then
                printf "${CYAN}│${NC}   ${GREEN}➜${NC} %-45s ${CYAN}│${NC}\n" "$group_line"
            fi
        done
    fi
    
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"
}

# Функция для вывода списка всех пользователей с группами
list_users() {
    print_header "СПИСОК ВСЕХ ПОЛЬЗОВАТЕЛЕЙ"
    
    local users=$(ipa user-find --pkey-only --raw 2>/dev/null | grep "uid:" | awk '{print $2}')
    local user_count=0
    
    if [ -z "$users" ]; then
        echo -e "${RED}Пользователи не найдены${NC}"
        return
    fi
    
    echo "$users" | while IFS= read -r username; do
        if [[ ! -z "$username" ]]; then
            ((user_count++))
            
            # Получаем имя и фамилию
            local fullname=$(ipa user-show "$username" --raw 2>/dev/null | grep -E "givenname:|sn:" | awk '{print $2}' | tr '\n' ' ')
            
            # Получаем группы (только прямые, без Indirect Member)
            local groups=$(ipa user-show "$username" 2>/dev/null | grep "Member of groups:" | sed 's/Member of groups://' | sed 's/, /,/g' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v "^$" | head -3)
            local groups_count=$(ipa user-show "$username" 2>/dev/null | grep "Member of groups:" | sed 's/Member of groups://' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v "^$" | wc -l)
            
            # Форматируем вывод
            printf "${GREEN}%3d.${NC} ${YELLOW}%-15s${NC} ${WHITE}%-25s${NC}" "$user_count" "$username" "$fullname"
            
            if [ ! -z "$groups" ]; then
                local first_group=$(echo "$groups" | head -1)
                printf " ${CYAN}Группы:${NC} ${GREEN}%s${NC}" "$first_group"
                
                if [ "$groups_count" -gt 1 ]; then
                    printf " ${YELLOW}(+%d групп)${NC}" "$((groups_count - 1))"
                fi
            else
                printf " ${RED}Нет групп${NC}"
            fi
            
            echo
        fi
    done
    
    print_separator
}

# Функция для детального просмотра пользователя
show_user() {
    print_header "ДЕТАЛЬНАЯ ИНФОРМАЦИЯ"
    
    if [ -z "$2" ]; then
        read -p "Введите имя пользователя: " username
    else
        username="$2"
    fi
    
    print_user_info "$username"
}

# Функция для добавления пользователя
add_user() {
    print_header "ДОБАВЛЕНИЕ НОВОГО ПОЛЬЗОВАТЕЛЯ"
    
    read -p "Имя пользователя: " username
    read -p "Имя: " firstname
    read -p "Фамилия: " lastname
    read -s -p "Пароль: " password
    echo
    read -s -p "Подтвердите пароль: " password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}Пароли не совпадают!${NC}"
        return 1
    fi
    
    read -p "Email (опционально): " email
    read -p "Группы (через запятую, опционально): " groups
    
    echo -e "\n${YELLOW}Создание пользователя...${NC}"
    
    # Создание пользователя
    local cmd="ipa user-add \"$username\" --first=\"$firstname\" --last=\"$lastname\""
    
    if [ ! -z "$email" ]; then
        cmd="$cmd --email=\"$email\""
    fi
    
    eval $cmd > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Пользователь $username создан${NC}"
        
        # Установка пароля
        echo -e "$password\n$password" | ipa passwd "$username" > /dev/null 2>&1
        
        # Добавление в группы
        if [ ! -z "$groups" ]; then
            IFS=',' read -ra GROUP_ARRAY <<< "$groups"
            for group in "${GROUP_ARRAY[@]}"; do
                group=$(echo "$group" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                ipa group-add-member "$group" --users="$username" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Добавлен в группу: $group${NC}"
                else
                    echo -e "${RED}✗ Ошибка добавления в группу: $group${NC}"
                fi
            done
        fi
        
        echo -e "\n${GREEN}Информация о созданном пользователе:${NC}"
        print_user_info "$username"
    else
        echo -e "${RED}✗ Ошибка создания пользователя (возможно уже существует)${NC}"
    fi
}

# Функция для удаления пользователя
delete_user() {
    print_header "УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ"
    
    if [ -z "$2" ]; then
        read -p "Имя пользователя для удаления: " username
    else
        username="$2"
    fi
    
    # Показываем информацию перед удалением
    print_user_info "$username"
    
    read -p "Вы уверены, что хотите удалить пользователя $username? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
        ipa user-del "$username" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Пользователь $username удален${NC}"
        else
            echo -e "${RED}✗ Ошибка удаления пользователя${NC}"
        fi
    else
        echo -e "${YELLOW}Операция отменена${NC}"
    fi
}

# Функция для блокировки/разблокировки пользователя
toggle_user() {
    local action="$1"
    local username="$2"
    
    if [ "$action" = "disable" ]; then
        print_header "БЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ"
    else
        print_header "РАЗБЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ"
    fi
    
    if [ -z "$username" ]; then
        read -p "Имя пользователя: " username
    fi
    
    # Показываем информацию перед изменением
    print_user_info "$username"
    
    if [ "$action" = "disable" ]; then
        ipa user-disable "$username" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Пользователь $username заблокирован${NC}"
        else
            echo -e "${RED}✗ Ошибка блокировки пользователя${NC}"
        fi
    else
        ipa user-enable "$username" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Пользователь $username разблокирован${NC}"
        else
            echo -e "${RED}✗ Ошибка разблокировки пользователя${NC}"
        fi
    fi
}

# Функция для поиска пользователей
search_users() {
    print_header "ПОИСК ПОЛЬЗОВАТЕЛЕЙ"
    
    read -p "Введите строку для поиска: " search_string
    
    local results=$(ipa user-find "$search_string" 2>/dev/null | grep -B1 -A5 "User login:" | sed 's/--//g')
    
    if [ -z "$results" ]; then
        echo -e "${RED}Пользователи не найдены${NC}"
        return
    fi
    
    echo -e "${GREEN}Найденные пользователи:${NC}\n"
    
    local current_user=""
    echo "$results" | while IFS= read -r line; do
        if [[ "$line" =~ "User login:" ]]; then
            current_user=$(echo "$line" | awk '{print $3}')
            echo -e "${YELLOW}┌────────────────────────────────────┐${NC}"
        elif [[ "$line" =~ "First name:" ]]; then
            echo -e "${CYAN}│${NC} Пользователь: ${GREEN}$current_user${NC}"
            echo -e "${CYAN}│${NC} $line"
        elif [[ ! -z "$line" ]]; then
            echo -e "${CYAN}│${NC} $line"
        fi
    done
    echo -e "${YELLOW}└────────────────────────────────────┘${NC}"
}

# Функция для показа статистики
show_stats() {
    print_header "СТАТИСТИКА"
    
    local total_users=$(ipa user-find --pkey-only --raw 2>/dev/null | grep -c "uid:")
    local active_users=$(ipa user-find --pkey-only --raw 2>/dev/null | grep -c "uid:" || echo "0")
    local total_groups=$(ipa group-find --pkey-only --raw 2>/dev/null | grep -c "cn:")
    
    echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE} Общая статистика FreeIPA            ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC} ${YELLOW}Всего пользователей:${NC} %10d ${CYAN}│${NC}\n" "$total_users"
    printf "${CYAN}│${NC} ${GREEN}Активных пользователей:${NC} %7d ${CYAN}│${NC}\n" "$active_users"
    printf "${CYAN}│${NC} ${BLUE}Всего групп:${NC} %16d ${CYAN}│${NC}\n" "$total_groups"
    echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
}

# Главное меню
show_menu() {
    clear
    print_header "УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ FREEIPA"
    echo -e "${GREEN}1.${NC} ${WHITE}Показать всех пользователей${NC}"
    echo -e "${GREEN}2.${NC} ${WHITE}Показать информацию о пользователе${NC}"
    echo -e "${GREEN}3.${NC} ${WHITE}Добавить пользователя${NC}"
    echo -e "${GREEN}4.${NC} ${WHITE}Удалить пользователя${NC}"
    echo -e "${GREEN}5.${NC} ${WHITE}Заблокировать пользователя${NC}"
    echo -e "${GREEN}6.${NC} ${WHITE}Разблокировать пользователя${NC}"
    echo -e "${GREEN}7.${NC} ${WHITE}Поиск пользователей${NC}"
    echo -e "${GREEN}8.${NC} ${WHITE}Статистика${NC}"
    echo -e "${GREEN}0.${NC} ${RED}Выход${NC}"
    print_separator
    echo -n "Выберите действие [0-8]: "
}

# Основная логика
main() {
    # Проверка аутентификации
    if ! klist -s 2>/dev/null; then
        echo -e "${YELLOW}Требуется аутентификация в FreeIPA${NC}"
        read -s -p "Введите пароль администратора: " ADMIN_PASS
        echo
        
        echo "$ADMIN_PASS" | kinit admin 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${RED}Ошибка аутентификации${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Аутентификация успешна${NC}\n"
    fi
    
    # Обработка аргументов командной строки
    if [ $# -gt 0 ]; then
        case $1 in
            list)    list_users ;;
            show)    show_user "$@" ;;
            add)     add_user ;;
            delete)  delete_user "$@" ;;
            disable) toggle_user "disable" "$2" ;;
            enable)  toggle_user "enable" "$2" ;;
            search)  search_users ;;
            stats)   show_stats ;;
            help)    
                print_header "СПРАВКА"
                echo "Использование: $0 {list|show|add|delete|disable|enable|search|stats|help} [username]"
                echo
                echo "Примеры:"
                echo "  $0 list              - показать всех пользователей"
                echo "  $0 show username     - показать информацию о пользователе"
                echo "  $0 add               - добавить пользователя"
                echo "  $0 delete username   - удалить пользователя"
                echo "  $0 disable username  - заблокировать пользователя"
                echo "  $0 enable username   - разблокировать пользователя"
                echo "  $0 search            - поиск пользователей"
                echo "  $0 stats             - показать статистику"
                ;;
            *)
                echo -e "${RED}Неизвестная команда: $1${NC}"
                echo "Используйте: $0 help"
                exit 1
                ;;
        esac
    else
        # Интерактивный режим
        while true; do
            show_menu
            read choice
            
            case $choice in
                1) list_users ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                2) show_user ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                3) add_user ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                4) delete_user ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                5) toggle_user "disable" ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                6) toggle_user "enable" ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                7) search_users ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                8) show_stats ; echo -e "\nНажмите Enter для продолжения..."; read ;;
                0) 
                    echo -e "${GREEN}До свидания!${NC}"
                    exit 0
                    ;;
                *) echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"; sleep 1 ;;
            esac
        done
    fi
}

# Запуск основной функции с аргументами командной строки
main "$@"
