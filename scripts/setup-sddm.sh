#!/bin/bash

# --- 1. Define Your "Master" Avatar ---
# Make sure this file exists before running!
SOURCE_AVATAR="$HOME/.config/avatar.jpg"

if [ ! -f "$SOURCE_AVATAR" ]; then
    echo "Error: Master avatar not found at $SOURCE_AVATAR"
    echo "Please copy your avatar there and run this script again."
    exit 1
fi

# --- 2. Define All Destination Paths ---
SDDM_BG_PATH="/usr/share/sddm/themes/sddm-cryo-theme/background.png"
SDDM_AVATAR_PATH="/usr/share/sddm/themes/sddm-cryo-theme/avatar.png"
HYPRLOCK_AVATAR_PATH="$HOME/.config/hypr/hyprlock/avatar.jpg"


# --- 3. Set SDDM File Permissions (The sudo part) ---
echo "Setting up permissions in /usr/share/sddm/..."

# Create the empty files as root
sudo touch "$SDDM_BG_PATH"
sudo touch "$SDDM_AVATAR_PATH"

# Change the file OWNER to you
sudo chown $USER:$USER "$SDDM_BG_PATH"
sudo chown $USER:$USER "$SDDM_AVATAR_PATH"

# Ensure the 'sddm' user can still READ them
sudo chmod 644 "$SDDM_BG_PATH"
sudo chmod 644 "$SDDM_AVATAR_PATH"

echo "Permissions set."


# --- 4. Copy Initial Avatars (The User part) ---
echo "Copying initial avatars..."

# Ensure Hyprlock config directory exists
mkdir -p "$HOME/.config/hypr/hyprlock"

# Copy to SDDM (no sudo needed)
cp "$SOURCE_AVATAR" "$SDDM_AVATAR_PATH"

# Copy and convert for Hyprlock (no sudo needed)
magick "$SOURCE_AVATAR" "$HYPRLOCK_AVATAR_PATH"

echo "------------------------------------------------"
echo "Setup Complete!"
echo "You can now run your wallpaper script."
echo "You do not need to run this setup script again."
echo "------------------------------------------------"
