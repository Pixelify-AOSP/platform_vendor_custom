#!/bin/bash

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

findPayloadOffset() {
    build=$1
    python3 -c '
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
' "$build"
}

if [ "${ASCP_BUILDTYPE}" != "OFFICIAL" ]; then
    exit 0
fi

if ! [ "$1" ]; then
    echo -e "${RED}Usage: $0 <zip_path> [device]${NC}"
    echo -e "${YELLOW}Note: device is optional, extracted from filename if not provided${NC}"
    if ! return 0 &> /dev/null; then
        exit 1
    fi
fi

ZIP_PATH="$1"
DEVICE="$2"

if [ ! -f "$ZIP_PATH" ]; then
    echo -e "${RED}Error: File not found at $ZIP_PATH${NC}"
    if ! return 0 &> /dev/null; then
        exit 1
    fi
fi

file_dir=$(dirname "$ZIP_PATH")
file_name=$(basename "$ZIP_PATH")

if [ -z "$DEVICE" ]; then
    DEVICE=$(echo $file_name | cut -d'-' -f4)
fi

if [ -n "${ASCP_BUILDTYPE}" ]; then
    buildtype=$(echo "${ASCP_BUILDTYPE}" | tr '[:upper:]' '[:lower:]')
    output_filename="full_${buildtype}.json"
else
    output_filename="full_unofficial.json"
fi

md5_hash=$(md5sum "$ZIP_PATH" | cut -d' ' -f1)
datetime=$(date +%s)

BASE_URL="https://sourceforge.net/projects/project-ascp/files/${DEVICE}"

echo -e "${GREEN}Generating OpenDelta JSON: ${YELLOW}${output_filename}${NC}"

isPayload=0
[ -f payload_properties.txt ] && rm payload_properties.txt
if unzip "$ZIP_PATH" payload_properties.txt 2>/dev/null; then
    isPayload=1
    offset=$(findPayloadOffset "$ZIP_PATH")
    keyPairs=$(cat payload_properties.txt | sed "s/=/\": \"/" | sed 's/^/      \"/' | sed 's/$/\"\,/')
    keyPairs=${keyPairs%?}
    [ -f payload_properties.txt ] && rm payload_properties.txt
fi

{
    echo "{"
    echo "  \"response\": ["
    echo "    {"
    echo "      \"datetime\": ${datetime},"
    echo "      \"filename\": \"${file_name}\","
    echo "      \"url\": \"${BASE_URL}/${file_name}\","
    echo -n "      \"md5\": \"${md5_hash}\""
} > "${file_dir}/${output_filename}"

if [[ $isPayload == 1 ]]; then
    {
        echo ","
        echo "      \"payload\": ["
        echo "        {"
        echo "          \"offset\": ${offset},"
        echo "${keyPairs}"
        echo "        }"
        echo "      ]"
    } >> "${file_dir}/${output_filename}"
fi

{
    echo "    }"
    echo "  ]"
    echo "}"
} >> "${file_dir}/${output_filename}"

echo -e "${GREEN}Done generating ${YELLOW}${output_filename}${NC}"
echo "${file_dir}/${output_filename}"
