#!/bin/bash
echo "=== Users ==="
getent passwd | awk -F: '{print $1, $3, $4, $6, $7}'
echo "=== Groups ==="
getent group | awk -F: '{print $1, $3}'
echo "=== chleni group ==="
for g in $(getent group | cut -d: -f1); do echo "$g: $(getent group $g | cut -d: -f4)"; done
