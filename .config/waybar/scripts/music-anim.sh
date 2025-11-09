#!/bin/bash

# --- Configuration ---
IMG_DIR="$HOME/.config/waybar/music-anim"
STATE_FILE="/tmp/waybar_music_anim.state"
# --- End Configuration ---

# Ensure the state file exists
[ -f $STATE_FILE ] || echo 0 > $STATE_FILE

# --- Auto-discovery (Finds ALL images) ---
FRAMES=()
while IFS= read -r -d $'\0' file; do
    FRAMES+=("$file")
done < <(find "$IMG_DIR" -maxdepth 1 \
    \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.gif" \) \
    -print0 | sort -z)

FRAME_COUNT=${#FRAMES[@]}

# --- Get Current State ---
# This is the index of the frame we are *currently* showing
CURRENT_INDEX=$(cat $STATE_FILE)

# --- Sanity Checks ---
if [ $FRAME_COUNT -eq 0 ]; then
    echo "{\"text\": \"\"}" # Output nothing if no images
    exit 0
fi

if [ $CURRENT_INDEX -ge $FRAME_COUNT ]; then
    CURRENT_INDEX=0 # Reset index if files were deleted
fi

# --- Logic: Animate or Freeze ---
PLAYER_STATUS=$(playerctl status 2>/dev/null)

if [ "$PLAYER_STATUS" = "Playing" ]; then
    # Music is playing: Advance the index
    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % FRAME_COUNT ))
    
    # Save the *new* index that we are about to display
    echo $CURRENT_INDEX > $STATE_FILE
fi
# If not playing, CURRENT_INDEX is *not* changed,
# so the script will just output the same frame again.

# --- Output ---
# Always output the frame for the (potentially new) CURRENT_INDEX
CURRENT_FRAME_PATH="${FRAMES[$CURRENT_INDEX]}"
echo "{\"text\": \"<span><img src='$CURRENT_FRAME_PATH' /></span>\"}"
