#!/bin/bash

# Directory where your app templates are stored
TEMPLATE_DIR="$HOME/.config/wallbash"

# Global variable to hold the palette file path
wallbashOut=""


apply_template() {
    local APP_NAME="$1"
    local TEMPLATE_FILE="$TEMPLATE_DIR/$APP_NAME.dcol"
    
    # Check if the template exists
    if [ ! -f "$TEMPLATE_FILE" ]; then
        # echo "Notice: Template for $APP_NAME not found."
        return 0
    fi
    
    # Check if the palette file exists (set by the main script)
    if [ ! -f "${wallbashOut}" ]; then
        echo "Error: Palette file not found at ${wallbashOut}"
        return 1
    fi
    
    # 1. Source the color variables from the .dcol file
    source <(grep -E 'dcol_[a-zA-Z0-9_]+=' "${wallbashOut}")

    # 2. Extract metadata: Target file path and Reload command
    local METADATA=$(head -n 1 "$TEMPLATE_FILE")
    local TARGET_FILE_RAW=$(echo "$METADATA" | cut -d'|' -f1 | sed 's/^#//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    local RELOAD_CMD=$(echo "$METADATA" | cut -d'|' -f2)

    # Use 'eval echo' to expand variables like $HOME and tildes (~)
    local TARGET_FILE=$(eval echo "$TARGET_FILE_RAW")

    # Check if the target file path is valid
    if [ -z "$TARGET_FILE" ]; then
        echo "Error: No target file path specified in $TEMPLATE_FILE"
        return 1
    fi
    
    # Check if the target's directory exists
    local TARGET_DIR=$(dirname "$TARGET_FILE")
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Error: Target directory for $APP_NAME does not exist: $TARGET_DIR"
        return 1
    fi

    echo "APPLYING: $APP_NAME theme to $TARGET_FILE"
    local TEMP_CONFIG=$(mktemp)
    local SED_COMMAND=""

    # 3. DYNAMICALLY find all tags and build the sed command
    local VAR_SUFFIXES=$(grep -oE '<wallbash_[^>]+>' "$TEMPLATE_FILE" | sed -e 's/<wallbash_//' -e 's/>//' | sort -u)
    
    if [ -z "$VAR_SUFFIXES" ]; then
        echo "Warning: No <wallbash_...> tags found in template $TEMPLATE_FILE."
    fi

    for suffix in $VAR_SUFFIXES; do
        local TEMPLATE_TAG="<wallbash_${suffix}>"
        local VAR_NAME="dcol_${suffix}" # The variable name we sourced (e.g., dcol_txt1)
        
        if [ -n "${!VAR_NAME}" ]; then
            local COLOR_VALUE="${!VAR_NAME}"
            # Escape '\' for rgba values
            COLOR_VALUE=$(echo "$COLOR_VALUE" | sed 's/\\/\\\\/g')
            SED_COMMAND+=" -e 's|${TEMPLATE_TAG}|${COLOR_VALUE}|g'"
        else
            echo "Warning: Color variable $VAR_NAME not found for tag $TEMPLATE_TAG."
        fi
    done
    
    # 4. Execute the substitution
    if [ -z "$SED_COMMAND" ]; then
         tail -n +2 "$TEMPLATE_FILE" > "$TEMP_CONFIG"
    else
        eval "tail -n +2 '$TEMPLATE_FILE' | sed $SED_COMMAND" > "$TEMP_CONFIG"
    fi

    # 5. Replace the actual config file
    mv "$TEMP_CONFIG" "$TARGET_FILE"
    
    # 6. Execute the application reload command
    if [ -n "$RELOAD_CMD" ]; then
        echo "RELOAD: Executing $RELOAD_CMD"
        eval "$RELOAD_CMD"
    fi

    echo "--- $APP_NAME theme applied ---"
}


# --- Main Script Logic ---

# 1. Check for input argument
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/image.png"
    exit 1
fi

# 2. Get the absolute path for the image file
IMAGE_PATH=$(realpath "$1")
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: Image file not found: $IMAGE_PATH"
    exit 1
fi

# 3. Define the palette file path by appending .dcol
PALETTE_PATH="${IMAGE_PATH}.dcol"

if [ ! -f "$PALETTE_PATH" ]; then
    echo "Error: Palette file not found at $PALETTE_PATH"
    echo "Please generate the palette first."
    exit 1
fi

# Set the global variable for the apply_template function
wallbashOut="$PALETTE_PATH"

# 4. Check if template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: Template directory $TEMPLATE_DIR not found."
    exit 1
fi

echo "--- Applying All Themes from $wallbashOut ---"

# 5. Loop through all templates and apply them
for TEMPLATE_FILE in "$TEMPLATE_DIR"/*.dcol; do
    
    # Check if any .dcol files were actually found
    if [ -f "$TEMPLATE_FILE" ]; then
        # Extract the app name from the filename
        APP_NAME=$(basename "$TEMPLATE_FILE" .dcol)
        
        # Call the apply_template function with the app name
        apply_template "$APP_NAME"
    fi
done

echo "--- All themes processed ---"
