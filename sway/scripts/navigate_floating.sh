#!/bin/bash
# \~/.config/sway/scripts/navigate_floating.sh
# Использование: navigate_floating.sh <left|right|up|down>

DIRECTION="$1"

case "$DIRECTION" in
    left)   swaymsg focus left ;;
    right)  swaymsg focus right ;;
    up)     swaymsg focus up ;;
    down)   swaymsg focus down ;;
    *)      exit 1 ;;
esac

# После смены фокуса — если окно floating, центрируем его
sleep 0.05
FOCUSED=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .type')

if [ "$FOCUSED" = "floating_con" ] || [ "$FOCUSED" = "con" ]; then
    # Проверяем, действительно ли floating
    IS_FLOATING=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | .type')
    if [ "$IS_FLOATING" = "floating_con" ]; then
        swaymsg move position center
    fi
fi