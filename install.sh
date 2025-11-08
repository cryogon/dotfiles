#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo ">>> yay not found. Installing..."

    echo ">>> Updating system and installing dependencies (git, base-devel)..."
    sudo pacman -Syu --needed base-devel git

    BUILD_DIR=$(mktemp -d)
    
    echo ">>> Cloning yay from AUR to $BUILD_DIR..."
    git clone https://aur.archlinux.org/yay.git "$BUILD_DIR"

    cd "$BUILD_DIR"

    echo ">>> Building and installing yay..."
    makepkg -si --noconfirm

    cd -
    rm -rf "$BUILD_DIR"

    echo ">>> yay installation complete."
else
    echo ">>> yay is already installed. Skipping."
fi

pacman_packages = (
  "kitty"
  "zsh"
  "cava"
  "waybar"
  "fastfetch"
  "imagemagick" # Render Images for fastfetch
  "lm_sensors" # For CPU/GPU Temps
  "radeontop" # AMD GPU INFO like temps etc.
  "btop"
  "nemo",
  "hyprshot"
  "hyprpicker"
)

aur_packages = (
  "catppuccin-gtk-theme-mocha" # Dark Theme For GTK Apps
  "nwg-look" # GUI Tool To Manage Themes
  "catppuccin-cursors-mocha" # Cursor Pack
  "papirus-icon-theme" # Icon Theme
  "papirus-folders-catppuccin-git" # To Further Customise Papirus Icon Theme
)


echo ">>> Installing Official Package..."
sudo pacman -S --needed "${pacman_packages[@]}"
echo ">>> Installed Official Packages Successfully"


echo ">>> Installing AUR Packages"
yay -S "${aur_packages[@]}"
echo ">>> Installed AUR Packages Successfully"

GTK_THEME="Catppuccin-Mocha-Standard-Blue-Dark"
ICON_THEME="papirus-catppuccin-mocha"
CURSOR_THEME="Catppuccin-Mocha-Cursors"
PAPIRUS_COLOR="cat-mocha-blue"


# Setting Dark Theme
# For GTK Apps
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
# Folder Icons
papirus-folders -C "$PAPIRUS_COLOR"
# For QT5 Apps
mkdir -p ~/.config/qt5ct
cat <<EOF > ~/.config/qt5ct/qt5ct.conf
[Appearance]
icon_theme=$ICON_THEME
style=gtk2

[General]
check_platform_theme=true

[Fonts]
fixed=@Variant(libertinus-mono)
general=@Variant(libertinus-sans)
EOF
