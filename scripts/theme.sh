WALLPAPER=$1
CURR_WALLPAPER_PATH="$HOME/.cache/current_wallpaper.png"

if [ ! -f "$WALLPAPER" ]; then
  echo "$WALLPAPER doesn't exist"
  exit 1
fi

# creatin symlink for current wallpaper for other services (like hyprlock)
ln -sf "$(readlink -f $WALLPAPER)" "$CURR_WALLPAPER_PATH"

awww img "$WALLPAPER"

if [ ! -f "$WALLPAPER.dcol" ]; then
  ~/dotfiles/scripts/wallbash.sh "$WALLPAPER"
fi

~/dotfiles/scripts/set-colors.sh "$WALLPAPER"
