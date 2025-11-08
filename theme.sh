#!/bin/bash
THEME_PATH="$HOME/.config/theme"
# Generating a theme file
if [ ! -f "$THEME_PATH" ]; then
  echo "DEFAULT" >> "$THEME_PATH"
fi

THEME="$(cat $THEME_PATH)"

case "$THEME" in
  "DEFAULT")
    THEME_BG_COLOR="#d0bcc9"
    THEME_TEXT_COLOR="#000000"
    THEME_BG2_COLOR="#e7ccc4"
    THEME_WALLPAPER="$HOME/Wallpapers/wallpaper-craft.png"
  ;;
  2|3) echo 2 or 3
  ;;
  *) echo default
  ;;
esac


echo "$THEME_WALLPAPER"

