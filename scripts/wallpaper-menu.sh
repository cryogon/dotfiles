#!/bin/bash

WALL_DIR="$HOME/dotfiles/Wallpapers"
THUMB_DIR="$HOME/.cache/wall-thumbnails"
SETTER_SCRIPT="$HOME/dotfiles/scripts/theme.sh" 

# This quietly updates any new wallpapers
~/dotfiles/scripts/create-thumbnails.sh &

r_override="window { width: 80%; } mainbox { margin: 5%; } inputbar { enabled: false; } element{orientation: vertical; padding: 1em;} element-icon{size: 16em;} element-text{horizontal-align: 0.5;} listview{columns: 5; spacing: 2em;}"

generate_list() {
    cd "$THUMB_DIR"
    for thumb in *.{jpg,jpeg,png,webp}; do
        # Check if file exists
        [ -f "$thumb" ] || continue

        # $thumb is just the "basename" (e.g., "wallpaper1.png")
        # We print the basename (as text) and the full path (as icon)
        echo -e "$thumb\0icon\x1f$THUMB_DIR/$thumb"
    done
}

selected_basename=$(generate_list | rofi -dmenu -p "" -theme-str "${r_override}")

if [ -n "$selected_basename" ]; then
    # Construct the full path to the *original* wallpaper
    full_path="$WALL_DIR/$selected_basename"

    "$SETTER_SCRIPT" "$full_path"
fi
