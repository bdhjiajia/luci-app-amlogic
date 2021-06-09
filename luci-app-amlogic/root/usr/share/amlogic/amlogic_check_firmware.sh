#!/bin/bash

# Set a fixed value
EMMC_NAME=$(lsblk | grep -oE '(mmcblk[0-9])' | sort | uniq)
FIRMWARE_DOWNLOAD_PATH="/mnt/${EMMC_NAME}p4"
TMP_CHECK_DIR="/tmp/amlogic"
AMLOGIC_SOC_FILE="/etc/flippy-openwrt-release"
START_LOG=${TMP_CHECK_DIR}"/amlogic_check_firmware.log"
LOG_FILE=${TMP_CHECK_DIR}"/amlogic.log"
TMP_CHECK_SERVER_FILE=${TMP_CHECK_DIR}"/amlogic_check_server_firmware_file.txt"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
[[ -d ${TMP_CHECK_DIR} ]] || mkdir -p ${TMP_CHECK_DIR}

# Log function
tolog() {
    echo -e "${1}" >$START_LOG
    echo -e "${LOGTIME} ${1}" >>$LOG_FILE
    [[ -z "${2}" ]] || exit 1
}

    # 01. Query local version information
    tolog "01. Query version information."
    CURRENT_KERNEL_V=$(ls /lib/modules/  2>/dev/null | grep -oE '^[1-9].[0-9]{1,2}.[0-9]+')
    tolog "01.01 current version: ${CURRENT_KERNEL_V}"
    MAIN_LINE_VER=$(echo "${CURRENT_KERNEL_V}" | cut -d '.' -f1)
    MAIN_LINE_MAJ=$(echo "${CURRENT_KERNEL_V}" | cut -d '.' -f2)
    MAIN_LINE_VERSION="${MAIN_LINE_VER}.${MAIN_LINE_MAJ}"
    sleep 3

    # 02. Download server version documentation
    tolog "02. Start checking the firmware version."
    CONFIG_CHECK_URL=$(uci get amlogic.config.amlogic_check_url 2>/dev/null)
    [[ ! -z "${CONFIG_CHECK_URL}" ]] || tolog "02.01 Invalid firmware download address." "1"
    rm -f "${TMP_CHECK_SERVER_FILE}" >/dev/null 2>&1 && sync
    wget -c "${CONFIG_CHECK_URL}" -O "${TMP_CHECK_SERVER_FILE}" >/dev/null 2>&1 && sync
    [[ -s ${TMP_CHECK_SERVER_FILE} ]] || tolog "02.02 Invalid firmware detection file." "1"

    source ${TMP_CHECK_SERVER_FILE} 2>/dev/null
    SERVER_FIRMWARE_URL=${amlogic_firmware_github_repository}
    RELEASES_TAG_KEYWORDS=${amlogic_firmware_tag_kerwords}
    FIRMWARE_SUFFIX=${amlogic_firmware_suffix}
    [[ ! -z "${SERVER_FIRMWARE_URL}" ]] || tolog "02.03 The custom firmware download address is invalid." "1"

    # 03. Version comparison
    tolog "03. Compare versions."
    source ${AMLOGIC_SOC_FILE} 2>/dev/null
    SOC=${SOC}
    [[ ! -z "${SOC}" ]] || tolog "03.01 The custom firmware soc is invalid." "1"
    tolog "03.02 Start downloading firmware ..."

    FIRMWARE_DOWNLOAD_URL="https:.*${RELEASES_TAG_KEYWORDS}.*${SOC}.*${MAIN_LINE_VERSION}.*${FIRMWARE_SUFFIX}"

    FIRMWARE_RELEASES_PATH=$(curl -s "https://api.github.com/repos/${SERVER_FIRMWARE_URL}/releases" | grep "browser_download_url" | grep -o "${FIRMWARE_DOWNLOAD_URL}" | head -n 1)
    FIRMWARE_DOWNLOAD_NAME="openwrt_${SOC}_v${MAIN_LINE_VERSION}_update${FIRMWARE_SUFFIX}"
    wget -c "${FIRMWARE_RELEASES_PATH}" -O "${FIRMWARE_DOWNLOAD_PATH}/${FIRMWARE_DOWNLOAD_NAME}" >/dev/null 2>&1 && sync
    if [[ "$?" -eq "0" && -s "${FIRMWARE_DOWNLOAD_PATH}/${FIRMWARE_DOWNLOAD_NAME}" ]]; then
        tolog "03.03 ${FIRMWARE_DOWNLOAD_NAME} download complete."
    else
        tolog "03.04 Invalid firmware download." "1"
    fi
    sleep 3

    tolog "04 The firmware is ready, you can update."
    sleep 3

    rm -rf ${TMP_CHECK_SERVER_FILE} >/dev/null 2>&1 && sync
    #echo '<a href="javascript:;" onclick="return amlogic_update(this, '"'${FIRMWARE_DOWNLOAD_NAME}'"')">Update</a>' >$START_LOG
    tolog '<input type="button" class="cbi-button cbi-button-reload" value="Update" onclick="return amlogic_update(this, '"'${FIRMWARE_DOWNLOAD_NAME}'"')"/>'

    exit 0

