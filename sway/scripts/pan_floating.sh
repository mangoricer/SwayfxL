#!/usr/bin/env bash

DIRECTION=$1
STEP=50

# Получаем ID всех плавающих окон на ТЕКУЩЕМ активном воркспейсе
WINDOW_IDS=$(swaymsg -t get_tree | jq -r '
  .. | select(.type? == "workspace" and .focused? == true) | 
  .. | select(.floating? == "auto_on" or .floating? == "user_on") | .id
')

# Если окон нет, просто выходим
if [ -z "$WINDOW_IDS" ]; then
    exit 0
fi

# Перемещаем каждое окно по очереди
for id in $WINDOW_IDS; do
    swaymsg "[con_id=$id] move $DIRECTION $STEP px"
done
