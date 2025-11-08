#!/usr/bin/env bash
#|---/ /+---------------------------------------------+---/ /|#
#|--/ /-| Script to generate color palette from image |--/ /-|#
#|-/ /--| Prasanth Rangan                             |-/ /--|#
#|/ /---+---------------------------------------------+/ /---|#


#// accent color profile

colorProfile="default"
wallbashCurve="32 50\n42 46\n49 40\n56 39\n64 38\n76 37\n90 33\n94 29\n100 20"
sortMode="auto"

while [ $# -gt 0 ] ; do
    case "$1" in
        -v|--vibrant) colorProfile="vibrant"
            wallbashCurve="18 99\n32 97\n48 95\n55 90\n70 80\n80 70\n88 60\n94 40\n99 24"
            ;;
        -p|--pastel) colorProfile="pastel"
            wallbashCurve="10 99\n17 66\n24 49\n39 41\n51 37\n58 34\n72 30\n84 26\n99 22"
            ;;
        -m|--mono) colorProfile="mono"
            wallbashCurve="10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
            ;;
        -c|--custom)
            shift
            if [ -n "${1}" ] && [[ "${1}" =~ ^([0-9]+[[:space:]][0-9]+\\n){8}[0-9]+[[:space:]][0-9]+$ ]] ; then
                    colorProfile="custom"
                    wallbashCurve="${1}"
            else
                echo "Error: Custom color curve format is incorrect ${1}"
                exit 1
            fi
            ;;
        -d|--dark) sortMode="dark"
            colSort=""
            ;;
        -l|--light) sortMode="light"
            colSort="-r"
            ;;
        *) break
            ;;
    esac
    shift
done


#// set variables

wallbashImg="${1}"
wallbashColors=4
wallbashFuzz=70
wallbashRaw="${2:-"${wallbashImg}"}.mpc"
wallbashOut="${2:-"${wallbashImg}"}.dcol"
wallbashCache="${2:-"${wallbashImg}"}.cache"


#// color modulations

pryDarkBri=116
pryDarkSat=110
pryDarkHue=88
pryLightBri=100
pryLightSat=100
pryLightHue=114
txtDarkBri=188
txtLightBri=16


#// input image validation

if [ -z "${wallbashImg}" ] || [ ! -f "${wallbashImg}" ] ; then
    echo "Error: Input file not found!"
    exit 1
fi

magick -ping "${wallbashImg}" -format "%t" info: &> /dev/null
if [ $? -ne 0 ] ; then
    echo "Error: Unsuppoted image format ${wallbashImg}"
    exit 1
fi

echo -e "wallbash ${colorProfile} profile :: ${sortMode} :: Colors ${wallbashColors} :: Fuzzy ${wallbashFuzz} :: \"${wallbashOut}\""
mkdir -p "${cacheDir}/${cacheThm}"
> "${wallbashOut}"


#// define functions
apply_template() {
    local APP_NAME="$1"
    local TEMPLATE_DIR="$HOME/.config/wallbash"
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
    
    # 1. Source the color variables from the generated .dcol file
    source <(grep -E 'dcol_[a-zA-Z0-9_]+=' "${wallbashOut}")

    # 2. Extract metadata: Target file path and Reload command
    local METADATA=$(head -n 1 "$TEMPLATE_FILE")
    local TARGET_FILE_RAW=$(echo "$METADATA" | cut -d'|' -f1 | sed 's/^#//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    local RELOAD_CMD=$(echo "$METADATA" | cut -d'|' -f2)

    # --- THIS IS THE FIX ---
    # Use 'eval echo' to expand variables like $HOME and tildes (~) in the path
    local TARGET_FILE=$(eval echo "$TARGET_FILE_RAW")
    # --- END FIX ---

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
            COLOR_VALUE=$(echo "$COLOR_VALUE" | sed 's/\\/\\\\/g')
            SED_COMMAND+=" -e 's|${TEMPLATE_TAG}|${COLOR_VALUE}|g'"
        else
            echo "Warning: Color variable $VAR_NAME not found in palette for tag $TEMPLATE_TAG."
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
#// END THEME APPLICATION FUNCTION

rgb_negative() {
    local inCol=$1
    local r=${inCol:0:2}
    local g=${inCol:2:2}
    local b=${inCol:4:2}
    local r16=$((16#$r))
    local g16=$((16#$g))
    local b16=$((16#$b))
    r=$(printf "%02X" $((255 - $r16)))
    g=$(printf "%02X" $((255 - $g16)))
    b=$(printf "%02X" $((255 - $b16)))
    echo "${r}${g}${b}"
}

rgba_convert() {
    local inCol=$1
    local r=${inCol:0:2}
    local g=${inCol:2:2}
    local b=${inCol:4:2}
    local r16=$((16#$r))
    local g16=$((16#$g))
    local b16=$((16#$b))
    printf "rgba(%d,%d,%d,\1341)\n" "$r16" "$g16" "$b16"
}

fx_brightness() {
    local inCol="${1}"
    local fxb=$(magick "${inCol}" -colorspace gray -format "%[fx:mean]" info:)
    if awk -v fxb="${fxb}" 'BEGIN {exit !(fxb < 0.5)}' ; then
        return 0 #// echo ":: ${fxb} :: dark :: ${inCol}"
    else
        return 1 #// echo ":: ${fxb} :: light :: ${inCol}"
    fi
}


#// quantize raw primary colors

magick -quiet -regard-warnings "${wallbashImg}"[0] -alpha off +repage "${wallbashRaw}"
readarray -t dcolRaw <<< $(magick "${wallbashRaw}" -depth 8 -fuzz ${wallbashFuzz}% +dither -kmeans ${wallbashColors} -depth 8 -format "%c" histogram:info: | sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,\2/p' | sort -r -n -k 1 -t ",")

if [ ${#dcolRaw[*]} -lt ${wallbashColors} ] ; then
    echo -e "RETRYING :: distinct colors ${#dcolRaw[*]} is less than ${wallbashColors} palette color..."
    readarray -t dcolRaw <<< $(magick "${wallbashRaw}" -depth 8 -fuzz ${wallbashFuzz}% +dither -kmeans $((wallbashColors + 2)) -depth 8 -format "%c" histogram:info: | sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,\2/p' | sort -r -n -k 1 -t ",")
fi


#// sort colors based on image brightness

if [ "${sortMode}" == "auto" ] ; then
    if fx_brightness "${wallbashRaw}" ; then
        sortMode="dark"
        colSort=""
    else
        sortMode="light"
        colSort="-r"
    fi
fi

echo "dcol_mode=\"${sortMode}\"" >> "${wallbashOut}"
dcolHex=($(echo  -e "${dcolRaw[@]:0:$wallbashColors}" | tr ' ' '\n' | awk -F ',' '{print $2}' | sort ${colSort}))
greyCheck=$(magick "${wallbashRaw}" -colorspace HSL -channel g -separate +channel -format "%[fx:mean]" info:)

if (( $(awk 'BEGIN {print ('"$greyCheck"' < 0.12)}') )); then
    wallbashCurve="10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
fi


#// loop for derived colors

for (( i=0; i<${wallbashColors}; i++ )) ; do


    #// generate missing primary colors

    if [ -z "${dcolHex[i]}" ] ; then

        if fx_brightness "xc:#${dcolHex[i - 1]}" ; then
            modBri=$pryDarkBri
            modSat=$pryDarkSat
            modHue=$pryDarkHue
        else
            modBri=$pryLightBri
            modSat=$pryLightSat
            modHue=$pryLightHue
        fi

        echo -e "dcol_pry$((i + 1)) :: regen missing color"
        dcol[i]=$(magick xc:"#${dcolHex[i - 1]}" -depth 8 -normalize -modulate ${modBri},${modSat},${modHue} -depth 8 -format "%c" histogram:info: | sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p')

    fi

    echo "dcol_pry$((i + 1))=\"${dcolHex[i]}\"" >> "${wallbashOut}"
    echo "dcol_pry$((i + 1))_rgba=\"$( rgba_convert "${dcolHex[i]}" )\"" >> "${wallbashOut}"


    #// generate primary text colors

    nTxt=$(rgb_negative ${dcolHex[i]})

    if fx_brightness "xc:#${dcolHex[i]}" ; then
        modBri=$txtDarkBri
    else
        modBri=$txtLightBri
    fi

    tcol=$(magick xc:"#${nTxt}" -depth 8 -normalize -modulate ${modBri},10,100 -depth 8 -format "%c" histogram:info: | sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p')
    echo "dcol_txt$((i + 1))=\"${tcol}\"" >> "${wallbashOut}"
    echo "dcol_txt$((i + 1))_rgba=\"$( rgba_convert "${tcol}" )\"" >> "${wallbashOut}"


    #// generate accent colors

    xHue=$(magick xc:"#${dcolHex[i]}" -colorspace HSB -format "%c" histogram:info: | awk -F '[hsb(,]' '{print $2}')
    acnt=1

    echo -e "${wallbashCurve}" | sort -n ${colSort} | while read -r xBri xSat
    do
        acol=$(magick xc:"hsb(${xHue},${xSat}%,${xBri}%)" -depth 8 -format "%c" histogram:info: | sed -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\2/p')
        echo "dcol_$((i + 1))xa${acnt}=\"${acol}\"" >> "${wallbashOut}"
        echo "dcol_$((i + 1))xa${acnt}_rgba=\"$( rgba_convert "${acol}" )\"" >> "${wallbashOut}"
        ((acnt++))
    done

done


#// cleanup temp cache

rm -f "${wallbashRaw}" "${wallbashCache}"

#// THEME APPLICATION BLOCK (Fully Automated)

echo -e "\n--- Applying All Themes ---"

TEMPLATE_DIR="$HOME/.config/wallbash"

# Check if the template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Warning: Template directory $TEMPLATE_DIR not found. Skipping theme application."
else
    # Loop through all .dcol files in the template directory
    for TEMPLATE_FILE in "$TEMPLATE_DIR"/*.dcol; do
        
        # Check if any .dcol files were actually found (handles empty dir)
        if [ -f "$TEMPLATE_FILE" ]; then
            # Extract the app name from the filename (e.g., "kitty" from "kitty.dcol")
            APP_NAME=$(basename "$TEMPLATE_FILE" .dcol)
            
            # Call the apply_template function with the app name
            apply_template "$APP_NAME"
        fi
    done
fi

echo "All themes processed."
