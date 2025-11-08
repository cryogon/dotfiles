WALLPAPER=$1
CURR_WALLPAPER_PATH="$HOME/.cache/current_wallpaper.png"

# creatin symlink for current wallpaper for other services (like hyprlock)
ln -sf "$(readlink -f $WALLPAPER)" "$CURR_WALLPAPER_PATH"

awww img "$WALLPAPER"

./wallbash.sh "$WALLPAPER"
