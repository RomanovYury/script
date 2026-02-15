#!/bin/bash

# Скрипт для управления пользователями FreeIPA
ACTION=${1:-list} # list, add, delete, disable, enable

case $ACTION in
    list)
        echo "=== Список пользователей ==="
        ipa user-find --all --raw | grep -E "uid:|givenname:|sn:|mail:"
        ;;
    
    add)
        read -p "Username: " username
        read -p "First name: " firstname
        read -p "Last name: " lastname
        read -s -p "Password: " password
        echo
        read -p "Group (optional): " group
        
        ipa user-add "$username" --first="$firstname" --last="$lastname"
        echo -e "$password\n$password" | ipa passwd "$username"
        
        if [ ! -z "$group" ]; then
            ipa group-add-member "$group" --users="$username"
        fi
        ;;
    
    delete)
        read -p "Username to delete: " username
        ipa user-del "$username"
        ;;
    
    disable)
        read -p "Username to disable: " username
        ipa user-disable "$username"
        ;;
    
    enable)
        read -p "Username to enable: " username
        ipa user-enable "$username"
        ;;
    
    *)
        echo "Использование: $0 {list|add|delete|disable|enable}"
        exit 1
        ;;
esac
