#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=mondrian
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
    -n | --no-cleanup)
        CLEAN_VENDOR=false
        ;;
    -k | --kang)
        KANG="--kang"
        ;;
    -s | --section)
        SECTION="${2}"
        shift
        CLEAN_VENDOR=false
        ;;
    *)
        SRC="${1}"
        ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function append_content() {
    local file="${1}"
    local string_to_append="${2}"
    local found=0
    
    if [ ! -f "${file}" ]; then
        echo "File ${file} not found"
        return 1
    fi
    
    while IFS= read -r line; do
        if [ "$line" == "$string_to_append" ]; then
            found=1
            break
        fi
    done < "${file}"

    if [ $found -eq 0 ]; then
        if [ -s "${file}" ] && [ "$(tail -c1 "${file}" | xxd -p)" != "0a" ]; then
            echo "" >> "${file}"
        fi
        echo "${string_to_append}" >> "${file}"
        echo "Appended '${string_to_append}' to ${file}"
    fi
}

function blob_fixup() {
    case "${1}" in
        vendor/etc/init/init.embmssl_server.rc)
            sed -i -n '/interface/!p' "${2}"
            ;;
        vendor/lib64/libsdmcore.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v33.so" "${2}"
            ;;
        vendor/lib/libsdmcore.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v33.so" "${2}"
            ;;
        vendor/lib64/soundfx/libmisoundfx.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib/soundfx/libmisoundfx.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib64/hw/displayfeature.default.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib/hw/displayfeature.default.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.security.keymint-service-qti | vendor/lib64/libqtikeymint.so)
            "${PATCHELF}" --add-needed "android.hardware.security.rkp-V1-ndk.so" "${2}"
            ;;
        vendor/bin/qcc-trd)
            "${PATCHELF}" --replace-needed "libgrpc++_unsecure.so" "libgrpc++_unsecure_prebuilt.so" "${2}"
            ;;
        vendor/lib/c2.dolby.client.so)
            "${PATCHELF}" --add-needed "libcodec2_hidl_shim.so" "${2}"
            ;;
        vendor/bin/hw/dolbycodec2 | vendor/bin/hw/vendor.dolby.hardware.dms@2.0-service | vendor/bin/hw/vendor.qti.media.c2@1.0-service)     
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib64/vendor.libdpmframework.so)     
            "${PATCHELF}" --add-needed "libhidlbase_shim.so" "${2}"
            ;;
        vendor/etc/qcril_database/upgrade/config/6.0_config.sql)
            [ "$2" = "" ] && return 0
            sed -i '/persist.vendor.radio.redir_party_num/ s/true/false/g' "${2}"
            ;;
        vendor/etc/camera/mondrian_enhance_motiontuning.xml|vendor/etc/camera/mondrian_motiontuning.xml)
            sed -i 's/xml=version/xml version/g' "${2}"
            ;;
        vendor/etc/camera/pureView_parameter.xml)
            sed -i 's/=\([0-9]\+\)>/="\1">/g' "${2}"
            ;;
        vendor/etc/seccomp_policy/atfwd@2.0.policy | vendor/etc/seccomp_policy/modemManager.policy | vendor/etc/seccomp_policy/sensors-qesdk.policy | vendor/etc/seccomp_policy/wfdhdcphalservice.policy)
            append_content "${2}" "gettid: 1"
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
