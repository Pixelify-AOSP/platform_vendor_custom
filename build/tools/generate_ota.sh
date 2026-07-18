#!/bin/bash
# Automated script to generate full and incremental OTA zip and json

DEVICE="$1"
if [ -z "$DEVICE" ]; then
    DEVICE="alioth"
fi

PRODUCT_OUT="out/target/product/${DEVICE}"
TARGET_FILES_DIR=$(find "${PRODUCT_OUT}/obj/PACKAGING/target_files_intermediates" -maxdepth 1 -name "*-target_files" 2>/dev/null | tail -n 1)
if [ -z "$TARGET_FILES_DIR" ]; then
    TARGET_FILES_DIR="${PRODUCT_OUT}/obj/PACKAGING/target_files_intermediates/custom_${DEVICE}-target_files"
fi
BACKUP_DIR="target_files/${DEVICE}"

# We only run if ASCP_BUILDTYPE is OFFICIAL
if [ "${ASCP_BUILDTYPE}" != "OFFICIAL" ]; then
    echo "Skipping OTA automation for non-OFFICIAL build."
    exit 0
fi

LOG_FILE="${PRODUCT_OUT}/ota_generation.log"
mkdir -p "${PRODUCT_OUT}"
cat /dev/null > "$LOG_FILE"

# Helper functions for SHA256 and Size
get_sha256() {
    python3 -c "
import hashlib, sys
h = hashlib.sha256()
with open(sys.argv[1], 'rb') as f:
    for chunk in iter(lambda: f.read(65536), b''):
        h.update(chunk)
print(h.hexdigest())
" "$1"
}

get_size() {
    du -h "$1" | awk '{print $1}'
}

# Determine new full zip filename
NEW_ZIP=$(find "${PRODUCT_OUT}" -maxdepth 1 -name "ASCP-v*-$DEVICE-OFFICIAL-*.zip" | sort | tail -n 1)
if [ -z "$NEW_ZIP" ]; then
    echo "Error: New full zip not found." | tee -a "$LOG_FILE"
    exit 1
fi
NEW_ZIP_NAME=$(basename "$NEW_ZIP")

# 1. Generate full json
echo "Generating full JSON..." >> "$LOG_FILE"
vendor/custom/build/tools/generate_update_json.sh "$NEW_ZIP" "$DEVICE" >> "$LOG_FILE" 2>&1

INC_GENERATED=false
INC_SKIP_REASON="No previous target files found"

# 2. Check if delta build was requested and if we have a previous build target files directory
if [ "${ASCP_DELTA_BUILD}" != "true" ]; then
    INC_SKIP_REASON="Delta build not requested (use --delta)"
    echo "Delta build not requested. Skipping incremental generation." >> "$LOG_FILE"
elif [ -d "${BACKUP_DIR}/previous_target_files" ]; then
    # Extract the previous zip filename from the backup dir
    PREV_ZIP_NAME=$(cat "${BACKUP_DIR}/previous_zip_name.txt" 2>/dev/null)
    
    if [ -n "$PREV_ZIP_NAME" ]; then
        PREV_SUFFIX=$(echo "$PREV_ZIP_NAME" | sed 's/\.zip$//' | awk -F'-' '{print $(NF-1) "-" $NF}')
        NEW_SUFFIX=$(echo "$NEW_ZIP_NAME" | sed 's/\.zip$//' | awk -F'-' '{print $(NF-1) "-" $NF}')
        INC_ZIP_NAME="ASCP-incremental-${DEVICE}-${PREV_SUFFIX}-to-${NEW_SUFFIX}.zip"
        INC_ZIP_PATH="${PRODUCT_OUT}/${INC_ZIP_NAME}"
        
        echo "Found previous target files. Generating incremental OTA..." >> "$LOG_FILE"
        echo "Running ota_from_target_files..." >> "$LOG_FILE"
        
        # Run ota_from_target_files (compiled hermetic host binary)
        out/host/linux-x86/bin/ota_from_target_files \
            -i "${BACKUP_DIR}/previous_target_files" \
            "${TARGET_FILES_DIR}" \
            "${INC_ZIP_PATH}" >> "$LOG_FILE" 2>&1
            
        if [ $? -eq 0 ]; then
            echo "Incremental OTA generated successfully: ${INC_ZIP_PATH}" >> "$LOG_FILE"
            
            # Generate the delta JSON using our python offset finder
            md5_hash=$(md5sum "${INC_ZIP_PATH}" | cut -d' ' -f1)
            datetime=$(date +%s)
            BASE_URL="https://sourceforge.net/projects/project-ascp/files/${DEVICE}"
            
            # Find payload offset for incremental zip
            offset=$(python3 -c '
import struct, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    try:
        info = z.getinfo("payload.bin")
        with open(sys.argv[1], "rb") as f:
            f.seek(info.header_offset)
            header = f.read(30)
            filename_len, extra_len = struct.unpack("<HH", header[26:30])
            print(info.header_offset + 30 + filename_len + extra_len)
    except Exception:
        print("0")
' "${INC_ZIP_PATH}")

            # Extract payload properties from incremental zip
            isPayload=0
            [ -f payload_properties.txt ] && rm payload_properties.txt
            if unzip "${INC_ZIP_PATH}" payload_properties.txt >> "$LOG_FILE" 2>&1; then
                isPayload=1
                keyPairs=$(cat payload_properties.txt | sed "s/=/\": \"/" | sed 's/^/      \"/' | sed 's/$/\"\,/')
                keyPairs=${keyPairs%?}
                [ -f payload_properties.txt ] && rm payload_properties.txt
            fi

            # Output to delta_official.json
            {
                echo "{"
                echo "  \"response\": ["
                echo "    {"
                echo "      \"datetime\": ${datetime},"
                echo "      \"filename\": \"${NEW_ZIP_NAME}\","
                echo "      \"expected_filename\": \"${PREV_ZIP_NAME}\","
                echo "      \"url\": \"${BASE_URL}/${INC_ZIP_NAME}\","
                echo -n "      \"md5\": \"${md5_hash}\""
            } > "${PRODUCT_OUT}/delta_official.json"

            if [[ $isPayload == 1 ]]; then
                {
                    echo ","
                    echo "      \"payload\": ["
                    echo "        {"
                    echo "          \"offset\": ${offset},"
                    echo "${keyPairs}"
                    echo "        }"
                    echo "      ]"
                } >> "${PRODUCT_OUT}/delta_official.json"
            fi

            {
                echo "    }"
                echo "  ]"
                echo "}"
            } >> "${PRODUCT_OUT}/delta_official.json"
            
            echo "Done generating delta_official.json" >> "$LOG_FILE"
            INC_GENERATED=true
        else
            echo "Failed to generate incremental OTA." >> "$LOG_FILE"
            INC_SKIP_REASON="Failed to generate incremental OTA (check ota_generation.log)"
        fi
    else
        echo "Warning: previous_zip_name.txt not found. Skipping incremental." >> "$LOG_FILE"
        INC_SKIP_REASON="previous_zip_name.txt not found"
    fi
else
    echo "No previous target files found. Skipping incremental generation." >> "$LOG_FILE"
fi

# 3. Backup current target files to become "previous" for the next run
echo "Backing up current target files for the next build..." >> "$LOG_FILE"
rm -rf "${BACKUP_DIR}/previous_target_files" >> "$LOG_FILE" 2>&1
mkdir -p "${BACKUP_DIR}" >> "$LOG_FILE" 2>&1
cp -R "${TARGET_FILES_DIR}" "${BACKUP_DIR}/previous_target_files" >> "$LOG_FILE" 2>&1
echo "${NEW_ZIP_NAME}" > "${BACKUP_DIR}/previous_zip_name.txt"
echo "Backup complete." >> "$LOG_FILE"

# 4. Generate beautiful final summary output
FULL_SHA=$(get_sha256 "$NEW_ZIP")
FULL_SIZE=$(get_size "$NEW_ZIP")

BLUE="\033[1;34m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
PURPLE="\033[1;35m"
YELLOW="\033[1;33m"
NC="\033[0m"

printf "${BLUE}========================================================================${NC}\n"
printf "${GREEN}                       ASCP OTA Package Complete                        ${NC}\n"
printf "${BLUE}========================================================================${NC}\n"
printf "${CYAN}Full OTA Package Details:${NC}\n"
printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "Package Zip" "$NEW_ZIP"
printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "SHA256" "$FULL_SHA"
printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "Size" "$FULL_SIZE"
printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "JSON Path" "${PRODUCT_OUT}/full_official.json"
echo ""

printf "${CYAN}Incremental OTA Package Details:${NC}\n"
if [ "$INC_GENERATED" = true ]; then
    INC_SHA=$(get_sha256 "$INC_ZIP_PATH")
    INC_SIZE=$(get_size "$INC_ZIP_PATH")
    printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "Package Zip" "$INC_ZIP_PATH"
    printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "SHA256" "$INC_SHA"
    printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "Size" "$INC_SIZE"
    printf "  ${CYAN}%-15s :${PURPLE} %s${NC}\n" "JSON Path" "${PRODUCT_OUT}/delta_official.json"
else
    printf "  ${CYAN}%-15s :${YELLOW} Skipped (%s)${NC}\n" "Status" "$INC_SKIP_REASON"
fi
echo ""
printf "${YELLOW}* Detailed compilation logs saved to: ${NC}%s\n" "${LOG_FILE}"
printf "${BLUE}========================================================================${NC}\n"
