WALLPAPER=$1
CURR_WALLPAPER_PATH="$HOME/.cache/current_wallpaper.png"

if [ ! -f "$WALLPAPER" ]; then
  echo "$WALLPAPER doesn't exist"
  exit 1
fi

# creatin symlink for current wallpaper for other services (like hyprlock)
ln -sf "$(readlink -f $WALLPAPER)" "$CURR_WALLPAPER_PATH"

awww img --transition-type grow --transition-pos 0.456,0.234 --transition-fps 180 "$WALLPAPER"

# if [ ! -f "$WALLPAPER.dcol" ]; then
#   ~/dotfiles/scripts/wallbash.sh "$WALLPAPER"
# fi
#
# ~/dotfiles/scripts/set-colors.sh "$WALLPAPER"
wal -l -i "$WALLPAPER"

SDDM_BACKGROUND_PATH="/usr/share/sddm/themes/sddm-cryo-theme/background.png"

# Use ImageMagick to create a blurred version
magick "$NEW_WALLPAPER" -blur 0x8 "/tmp/sddm_blur.png"

cp "/tmp/sddm_blur.png" "$SDDM_BACKGROUND_PATH"

echo "SDDM background updated!"
