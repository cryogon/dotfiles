#!/bin/bash

WALL_DIR="$HOME/dotfiles/Wallpapers"
THUMB_DIR="$HOME/.cache/wall-thumbnails"

# Ensure thumbnail directory exists
mkdir -p "$THUMB_DIR"

# Loop through all images in the wallpaper directory
for file in "$WALL_DIR"/*.{jpg,jpeg,png,webp}; do
    # Check if file exists
    [ -f "$file" ] || continue

    # Get just the filename (e.g., "wallpaper1.png")
    filename=$(basename "$file")

    # Define the full path for the thumbnail
    thumb_path="$THUMB_DIR/$filename"

    # If the thumbnail doesn't exist, create it
    if [ ! -f "$thumb_path" ]; then
        echo "Generating thumbnail for $filename..."
        # This command creates a 256x256 square, cropped from the center
        magick "$file" -resize 256x256^ -gravity center -extent 256x256 "$thumb_path"
    fi
done

echo "Thumbnail generation complete."
