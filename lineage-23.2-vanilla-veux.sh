#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# LineageOS 23.2 / Android 16 / VEUX-PEUX
# Vanilla build for Redmi Note 11 Pro 5G / Pro+ 5G
#
# Source baseline:
#   https://github.com/accupara/los23.2
#   branch: lineage-23.2
#
# Device:
#   xiaomi-sm6375-devs/android_device_xiaomi_veux
#
# Common:
#   xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common
#
# Hardware:
#   LineageOS/android_hardware_xiaomi
#
# Kernel:
#   CaesiumOS/kernel_xiaomi_sm6375
#   branch: 16-qpr2
#   pinned commit:
#   30e3b032c8f27780f6011bc61c4c4b655985c9bb
#
# BootControl:
#   LineageOS/android_hardware_qcom_bootctrl
#   branch: lineage-23.2-caf
#
# Vendor:
#   Xiaomi-sm6375-developers/vendor_xiaomi_veux
#   branch: bka
#
# Common vendor:
#   crdroidandroid/proprietary_vendor_xiaomi_sm6375-common
#   branch: 16.0
#
# IMPORTANT:
#   Vanilla build.
#   No GApps / MindTheGapps / NikGapps / BitGApps / OpenGApps.
#   No MiuiCamera / Dolby / ViPER4Android.
#   No 22.1-era GPT/audio/source patches are injected.
# ============================================================

ROM_BRANCH="${ROM_BRANCH:-lineage-23.2}"
SOURCE_MANIFEST="${SOURCE_MANIFEST:-https://github.com/accupara/los23.2.git}"

KERNEL_COMMIT="${KERNEL_COMMIT:-30e3b032c8f27780f6011bc61c4c4b655985c9bb}"

SOURCE_ROOT="${SOURCE_ROOT:-$PWD}"
OUTPUT_DIR="${OUTPUT_DIR:-$SOURCE_ROOT/imgs_output}"

PREFLIGHT_ONLY="${PREFLIGHT_ONLY:-0}"

# none = use prebuilt vendor trees
# adb  = extract from connected Android device
# dump = extract from a local ROM dump
EXTRACT_BLOBS="${EXTRACT_BLOBS:-none}"
BLOB_SOURCE="${BLOB_SOURCE:-}"

REPO_JOBS="${REPO_JOBS:-8}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"

DEVICE="veux"
PRODUCT="lineage_veux"

EXPECTED_PRODUCT_NAME="lineage_veux"
EXPECTED_KERNEL_CONFIG="veux_defconfig"

EXPECTED_KERNEL_PATH="kernel/xiaomi/sm6375"
EXPECTED_DEVICE_PATH="device/xiaomi/veux"
EXPECTED_COMMON_PATH="device/xiaomi/sm6375-common"
EXPECTED_VENDOR_PATH="vendor/xiaomi/veux"
EXPECTED_COMMON_VENDOR_PATH="vendor/xiaomi/sm6375-common"
EXPECTED_HARDWARE_PATH="hardware/xiaomi"
EXPECTED_BOOTCTRL_PATH="hardware/qcom-caf/bootctrl"

log() {
    printf '\n[%s] %s\n' "INFO" "$*"
}

warn() {
    printf '\n[%s] %s\n' "WARN" "$*" >&2
}

die() {
    printf '\n[%s] %s\n' "ERROR" "$*" >&2
    exit 1
}

on_error() {
    local ec=$?

    echo
    echo "============================================================"
    echo " BUILD SCRIPT FAILED"
    echo " exit_code=$ec"
    echo " line=${BASH_LINENO[0]:-unknown}"
    echo " command=${BASH_COMMAND:-unknown}"
    echo "============================================================"

    exit "$ec"
}

trap on_error ERR

cd "$SOURCE_ROOT"

# ============================================================
# 1. Host / Crave preflight
# ============================================================

log "Checking host tools"

for command in \
    git \
    repo \
    python3 \
    java \
    sed \
    grep \
    find \
    awk \
    sha256sum
do
    command -v "$command" >/dev/null 2>&1 || \
        die "Required command not found: $command"
done

if [ -x /opt/crave/resync.sh ]; then
    log "Crave resync helper detected"
else
    warn "/opt/crave/resync.sh not found; using normal repo sync"
fi

git --version
repo --version | head -n 1 || true
python3 --version
java -version 2>&1 | head -n 1

# ============================================================
# 2. Initialize LineageOS source
# ============================================================

log "Initializing LineageOS 23.2 source tree"

mkdir -p .repo

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

repo init \
    -u "$SOURCE_MANIFEST" \
    -b "$ROM_BRANCH" \
    --git-lfs \
    --depth=1

# ============================================================
# 3. Local manifest
# ============================================================

cat > .repo/local_manifests/veux.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

    <!-- VEUX device -->
    <project
        name="xiaomi-sm6375-devs/android_device_xiaomi_veux"
        path="device/xiaomi/veux"
        revision="lineage-23.2"
        clone-depth="1" />

    <!-- SM6375 common -->
    <project
        name="xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common"
        path="device/xiaomi/sm6375-common"
        revision="lineage-23.2"
        clone-depth="1" />

    <!-- Official LineageOS Xiaomi hardware -->
    <project
        name="LineageOS/android_hardware_xiaomi"
        path="hardware/xiaomi"
        revision="lineage-23.2"
        clone-depth="1" />

    <!-- Qualcomm A/B BootControl used by the 23.2 SM6375 tree -->
    <remove-project
        name="LineageOS/android_hardware_qcom_bootctrl"
        optional="true" />

    <project
        name="LineageOS/android_hardware_qcom_bootctrl"
        path="hardware/qcom-caf/bootctrl"
        revision="lineage-23.2-caf"
        clone-depth="1" />

    <!-- Android 16 VEUX kernel -->
    <project
        name="CaesiumOS/kernel_xiaomi_sm6375"
        path="kernel/xiaomi/sm6375"
        revision="30e3b032c8f27780f6011bc61c4c4b655985c9bb"
        clone-depth="1" />

    <!-- VEUX proprietary vendor -->
    <project
        name="Xiaomi-sm6375-developers/vendor_xiaomi_veux"
        path="vendor/xiaomi/veux"
        revision="bka"
        clone-depth="1" />

    <!-- SM6375 common proprietary vendor -->
    <project
        name="crdroidandroid/proprietary_vendor_xiaomi_sm6375-common"
        path="vendor/xiaomi/sm6375-common"
        revision="16.0"
        clone-depth="1" />

</manifest>
EOF

log "Local manifest created"

# ============================================================
# 4. Sync source
# ============================================================

log "Synchronizing source"

if [ -x /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync \
        -c \
        --force-sync \
        --no-clone-bundle \
        --no-tags \
        --optimized-fetch \
        --prune \
        -j"$REPO_JOBS"
fi

log "Source synchronization completed"

# ============================================================
# 5. Validate required repositories
# ============================================================

log "Validating required source directories"

for dir in \
    "$EXPECTED_DEVICE_PATH" \
    "$EXPECTED_COMMON_PATH" \
    "$EXPECTED_HARDWARE_PATH" \
    "$EXPECTED_BOOTCTRL_PATH" \
    "$EXPECTED_KERNEL_PATH" \
    "$EXPECTED_VENDOR_PATH" \
    "$EXPECTED_COMMON_VENDOR_PATH" \
    "hardware/qcom-caf/common/libqti-perfd-client" \
    "hardware/qcom-caf/sm8350" \
    "vendor/qcom/opensource/display"
do
    [ -d "$dir" ] || die "Missing required directory: $dir"
done

for repo_path in \
    "$EXPECTED_DEVICE_PATH" \
    "$EXPECTED_COMMON_PATH" \
    "$EXPECTED_HARDWARE_PATH" \
    "$EXPECTED_BOOTCTRL_PATH" \
    "$EXPECTED_KERNEL_PATH" \
    "$EXPECTED_VENDOR_PATH" \
    "$EXPECTED_COMMON_VENDOR_PATH"
do
    git -C "$repo_path" rev-parse --show-toplevel >/dev/null || \
        die "Not a valid git repository: $repo_path"
done

log "Required source repositories are present"

# ============================================================
# 6. Validate files directly referenced by the 23.2 tree
# ============================================================

log "Checking required build files"

for file in \
    "$EXPECTED_DEVICE_PATH/Android.bp" \
    "$EXPECTED_DEVICE_PATH/AndroidProducts.mk" \
    "$EXPECTED_DEVICE_PATH/BoardConfig.mk" \
    "$EXPECTED_DEVICE_PATH/device.mk" \
    "$EXPECTED_DEVICE_PATH/lineage_veux.mk" \
    "$EXPECTED_DEVICE_PATH/lineage.dependencies" \
    "$EXPECTED_DEVICE_PATH/proprietary-files.txt" \
    "$EXPECTED_DEVICE_PATH/extract-files.py" \
    "$EXPECTED_COMMON_PATH/Android.bp" \
    "$EXPECTED_COMMON_PATH/BoardConfigCommon.mk" \
    "$EXPECTED_COMMON_PATH/common.mk" \
    "$EXPECTED_COMMON_PATH/lineage.dependencies" \
    "$EXPECTED_COMMON_PATH/proprietary-files.txt" \
    "$EXPECTED_COMMON_PATH/extract-files.py" \
    "$EXPECTED_BOOTCTRL_PATH/aidl/Android.bp" \
    "$EXPECTED_BOOTCTRL_PATH/aidl/BootControl.cpp" \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" \
    "$EXPECTED_VENDOR_PATH/veux-vendor.mk" \
    "$EXPECTED_COMMON_VENDOR_PATH/sm6375-common-vendor.mk" \
    "hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt" \
    "hardware/qcom-caf/sm8350/audio/configs/holi/audio_effects.xml"
do
    [ -f "$file" ] || die "Missing required file: $file"
done

# ============================================================
# 7. Device / product validation
# ============================================================

log "Validating VEUX product configuration"

grep -q 'TARGET_KERNEL_CONFIG := veux_defconfig' \
    "$EXPECTED_DEVICE_PATH/BoardConfig.mk" || \
    die "VEUX BoardConfig does not select veux_defconfig"

grep -q 'TARGET_KERNEL_SOURCE := kernel/xiaomi/sm6375' \
    "$EXPECTED_COMMON_PATH/BoardConfigCommon.mk" || \
    die "Common BoardConfig does not select kernel/xiaomi/sm6375"

grep -q 'PRODUCT_NAME := lineage_veux' \
    "$EXPECTED_DEVICE_PATH/lineage_veux.mk" || \
    die "Unexpected PRODUCT_NAME"

grep -q 'PRODUCT_DEVICE := veux' \
    "$EXPECTED_DEVICE_PATH/lineage_veux.mk" || \
    die "Unexpected PRODUCT_DEVICE"

grep -q 'PRODUCT_USE_DYNAMIC_PARTITIONS := true' \
    "$EXPECTED_COMMON_PATH/common.mk" || \
    die "Dynamic partitions are not enabled in common.mk"

# ============================================================
# 8. Dependency validation
# ============================================================

log "Validating device dependencies"

grep -q 'android_device_xiaomi_sm6375-common' \
    "$EXPECTED_DEVICE_PATH/lineage.dependencies" || \
    die "VEUX dependency on sm6375-common is missing"

grep -q 'android_hardware_xiaomi' \
    "$EXPECTED_COMMON_PATH/lineage.dependencies" || \
    die "Common dependency on android_hardware_xiaomi is missing"

grep -q 'android_kernel_xiaomi_sm6375' \
    "$EXPECTED_COMMON_PATH/lineage.dependencies" || \
    die "Common dependency on android_kernel_xiaomi_sm6375 is missing"

# ============================================================
# 9. Kernel validation
# ============================================================

log "Validating kernel source"

ACTUAL_KERNEL_COMMIT="$(
    git -C "$EXPECTED_KERNEL_PATH" rev-parse HEAD
)"

echo "Expected kernel commit: $KERNEL_COMMIT"
echo "Actual kernel commit:   $ACTUAL_KERNEL_COMMIT"

[ "$ACTUAL_KERNEL_COMMIT" = "$KERNEL_COMMIT" ] || \
    die "Kernel commit mismatch"

grep -q 'CONFIG_QGKI=y' \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" || \
    die "Kernel config missing CONFIG_QGKI=y"

grep -q 'CONFIG_WT_QGKI=y' \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" || \
    die "Kernel config missing CONFIG_WT_QGKI=y"

grep -q 'CONFIG_LTO_CLANG=y' \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" || \
    die "Kernel config missing CONFIG_LTO_CLANG=y"

log "Kernel validation passed"

# ============================================================
# 10. Proprietary lists / vendor validation
# ============================================================

log "Validating proprietary-file manifests"

for list_file in \
    "$EXPECTED_DEVICE_PATH/proprietary-files.txt" \
    "$EXPECTED_COMMON_PATH/proprietary-files.txt"
do
    count="$(
        awk '
            !/^[[:space:]]*(#|$)/ { count++ }
            END { print count + 0 }
        ' "$list_file"
    )"

    [ "$count" -gt 0 ] || \
        die "Proprietary list is empty: $list_file"

    echo "$list_file: $count entries"
done

for vendor_tree in \
    "$EXPECTED_VENDOR_PATH" \
    "$EXPECTED_COMMON_VENDOR_PATH"
do
    if [ -z "$(find "$vendor_tree" -type f -print -quit)" ]; then
        die "Vendor tree is empty: $vendor_tree"
    fi

    log "Vendor tree populated: $vendor_tree"
done

# ============================================================
# 11. Optional proprietary blob extraction
# ============================================================

case "$EXTRACT_BLOBS" in
    none)
        log "Blob extraction disabled; using synced vendor repositories"
        ;;

    adb)
        command -v adb >/dev/null 2>&1 || \
            die "adb is required for EXTRACT_BLOBS=adb"

        (
            cd "$EXPECTED_DEVICE_PATH"
            PYTHONPATH=../../../tools/extract-utils \
                python3 ./extract-files.py
        )

        log "Proprietary blobs extracted from connected device"
        ;;

    dump)
        [ -n "$BLOB_SOURCE" ] || \
            die "BLOB_SOURCE is required for EXTRACT_BLOBS=dump"

        [ -d "$BLOB_SOURCE" ] || \
            die "BLOB_SOURCE directory does not exist: $BLOB_SOURCE"

        BLOB_SOURCE="$(cd "$BLOB_SOURCE" && pwd -P)"

        (
            cd "$EXPECTED_DEVICE_PATH"
            PYTHONPATH=../../../tools/extract-utils \
                python3 ./extract-files.py "$BLOB_SOURCE"
        )

        log "Proprietary blobs extracted from: $BLOB_SOURCE"
        ;;

    *)
        die "EXTRACT_BLOBS must be: none, adb, or dump"
        ;;
esac

# ============================================================
# 12. Do NOT inject 22.1-era modifications
# ============================================================

log "Verifying that no 22.1-era custom patches are being injected"

# Intentionally NOT modifying:
#   - hardware/qcom-caf/bootctrl source
#   - gpt-utils source
#   - BOARD_OPENSOURCE_DIR
#   - old Holi audio-config repository
#   - MIUI Camera references
#   - Dolby
#   - ViPER4Android
#   - XiaomiParts
#   - GApps / WITH_GMS
#
# The current 23.2 device/common trees remain authoritative.

if grep -RInE \
    'MindTheGapps|vendor/gapps|NikGapps|BitGApps|OpenGApps|WITH_GMS[[:space:]]*:?[[:space:]]*=[[:space:]]*true' \
    "$EXPECTED_DEVICE_PATH" \
    "$EXPECTED_COMMON_PATH" \
    2>/dev/null
then
    die "Unexpected GApps configuration found in device/common source"
fi

# ============================================================
# 13. Build environment
# ============================================================

export BUILD_USERNAME="${BUILD_USERNAME:-crave}"
export BUILD_HOSTNAME="${BUILD_HOSTNAME:-foss}"

# Retained as a configurable Crave compatibility variable.
export BUILD_BROKEN_MISSING_REQUIRED_MODULES="${BUILD_BROKEN_MISSING_REQUIRED_MODULES:-true}"

# ============================================================
# 14. Build environment setup
# ============================================================

log "Loading Android build environment"

# Android build scripts are not always nounset-safe.
set +u
source build/envsetup.sh
lunch "${PRODUCT}-userdebug"
set -u

# ============================================================
# 15. Resolve and validate final build configuration
# ============================================================

log "Resolving final product configuration"

TARGET_PRODUCT_RESOLVED="$(get_build_var TARGET_PRODUCT)"
TARGET_BUILD_VARIANT_RESOLVED="$(get_build_var TARGET_BUILD_VARIANT)"
TARGET_DEVICE_RESOLVED="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH_RESOLVED="$(get_build_var TARGET_ARCH)"
TARGET_KERNEL_SOURCE_RESOLVED="$(get_build_var TARGET_KERNEL_SOURCE)"
TARGET_KERNEL_CONFIG_RESOLVED="$(get_build_var TARGET_KERNEL_CONFIG)"
PRODUCT_OUT="$(get_build_var PRODUCT_OUT)"
DYNAMIC_PARTITIONS_RESOLVED="$(get_build_var PRODUCT_USE_DYNAMIC_PARTITIONS)"
PRODUCT_PACKAGES_RESOLVED="$(get_build_var PRODUCT_PACKAGES)"

echo
echo "Resolved configuration:"
echo "  TARGET_PRODUCT       = $TARGET_PRODUCT_RESOLVED"
echo "  TARGET_BUILD_VARIANT = $TARGET_BUILD_VARIANT_RESOLVED"
echo "  TARGET_DEVICE        = $TARGET_DEVICE_RESOLVED"
echo "  TARGET_ARCH          = $TARGET_ARCH_RESOLVED"
echo "  TARGET_KERNEL_SOURCE = $TARGET_KERNEL_SOURCE_RESOLVED"
echo "  TARGET_KERNEL_CONFIG = $TARGET_KERNEL_CONFIG_RESOLVED"
echo "  PRODUCT_OUT          = $PRODUCT_OUT"
echo "  DYNAMIC_PARTITIONS   = $DYNAMIC_PARTITIONS_RESOLVED"
echo

[ "$TARGET_PRODUCT_RESOLVED" = "$EXPECTED_PRODUCT_NAME" ] || \
    die "Unexpected TARGET_PRODUCT: $TARGET_PRODUCT_RESOLVED"

[ "$TARGET_DEVICE_RESOLVED" = "$DEVICE" ] || \
    die "Unexpected TARGET_DEVICE: $TARGET_DEVICE_RESOLVED"

[ "$TARGET_ARCH_RESOLVED" = "arm64" ] || \
    die "Unexpected TARGET_ARCH: $TARGET_ARCH_RESOLVED"

[ "$TARGET_KERNEL_SOURCE_RESOLVED" = "$EXPECTED_KERNEL_PATH" ] || \
    die "Unexpected kernel source: $TARGET_KERNEL_SOURCE_RESOLVED"

[[ "$TARGET_KERNEL_CONFIG_RESOLVED" == *"$EXPECTED_KERNEL_CONFIG"* ]] || \
    die "veux_defconfig was not resolved"

[ "$DYNAMIC_PARTITIONS_RESOLVED" = "true" ] || \
    die "Dynamic partitions were not enabled"

[ -n "$PRODUCT_OUT" ] || \
    die "PRODUCT_OUT is empty"

# ============================================================
# 16. Verify packages directly required by the 23.2 tree
# ============================================================

has_package() {
    local wanted="$1"

    awk -v wanted="$wanted" '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == wanted) {
                    found = 1
                }
            }
        }
        END {
            exit(found ? 0 : 1)
        }
    ' <<< "$PRODUCT_PACKAGES_RESOLVED"
}

for package in \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery \
    fastbootd
do
    has_package "$package" || \
        die "Required resolved package missing: $package"
done

log "Required BootControl / fastbootd packages resolved"

# ============================================================
# 17. Preflight-only mode
# ============================================================

if [ "$PREFLIGHT_ONLY" = "1" ] || [ "$PREFLIGHT_ONLY" = "true" ]; then

    echo
    echo "============================================================"
    echo " PREFLIGHT PASSED"
    echo "============================================================"
    echo "Product : $TARGET_PRODUCT_RESOLVED"
    echo "Device  : $TARGET_DEVICE_RESOLVED"
    echo "Arch    : $TARGET_ARCH_RESOLVED"
    echo "Kernel  : $ACTUAL_KERNEL_COMMIT"
    echo "Config  : $TARGET_KERNEL_CONFIG_RESOLVED"
    echo "Variant : $TARGET_BUILD_VARIANT_RESOLVED"
    echo "Output  : $PRODUCT_OUT"
    echo "============================================================"

    exit 0
fi

# ============================================================
# 18. Targeted QTI BootControl pre-build test
# ============================================================

log "Testing libgptutils.qti before the full ROM build"

m libgptutils.qti -j"$BUILD_JOBS"

log "libgptutils.qti pre-build test passed"

# ============================================================
# 19. Full LineageOS 23.2 Vanilla build
# ============================================================

log "Starting LineageOS 23.2 Vanilla build"

echo "Running:"
echo "  mka -j$BUILD_JOBS bacon"
echo

mka -j"$BUILD_JOBS" bacon

# ============================================================
# 20. Collect artifacts
# ============================================================

log "Collecting build artifacts"

[ -d "$PRODUCT_OUT" ] || \
    die "Product output directory missing: $PRODUCT_OUT"

mkdir -p "$OUTPUT_DIR"

shopt -s nullglob

ZIP_ARTIFACTS=(
    "$PRODUCT_OUT"/lineage-*.zip
)

if (( ${#ZIP_ARTIFACTS[@]} == 0 )); then
    shopt -u nullglob
    die "Build completed but no LineageOS ZIP was found in $PRODUCT_OUT"
fi

cp -f -- "${ZIP_ARTIFACTS[@]}" "$OUTPUT_DIR/"

for checksum_file in \
    "$PRODUCT_OUT"/lineage-*.zip.md5sum \
    "$PRODUCT_OUT"/lineage-*.zip.sha256sum
do
    [ -f "$checksum_file" ] && \
        cp -f "$checksum_file" "$OUTPUT_DIR/" || true
done

for image in \
    boot.img \
    dtbo.img \
    recovery.img \
    super.img \
    vendor_boot.img \
    vbmeta.img \
    vbmeta_system.img
do
    if [ -f "$PRODUCT_OUT/$image" ]; then
        cp -f "$PRODUCT_OUT/$image" "$OUTPUT_DIR/"
    fi
done

shopt -u nullglob

# Useful build metadata.
for file in \
    "$PRODUCT_OUT/installed-files.txt"
do
    [ -f "$file" ] && \
        cp -f "$file" "$OUTPUT_DIR/" || true
done

# ============================================================
# 21. SHA256 checksums
# ============================================================

log "Generating SHA256 checksums"

(
    cd "$OUTPUT_DIR"

    find . \
        -maxdepth 1 \
        -type f \
        ! -name 'SHA256SUMS.txt' \
        -print0 |
        sort -z |
        xargs -0 -r sha256sum
) | tee "$OUTPUT_DIR/SHA256SUMS.txt"

# ============================================================
# 22. Final report
# ============================================================

echo
echo "============================================================"
echo " BUILD FINISHED SUCCESSFULLY"
echo "============================================================"
echo "ROM branch          : $ROM_BRANCH"
echo "Product             : $TARGET_PRODUCT_RESOLVED"
echo "Device              : $TARGET_DEVICE_RESOLVED"
echo "Build variant       : $TARGET_BUILD_VARIANT_RESOLVED"
echo "Kernel              : CaesiumOS/kernel_xiaomi_sm6375"
echo "Kernel commit       : $ACTUAL_KERNEL_COMMIT"
echo "Kernel config       : $EXPECTED_KERNEL_CONFIG"
echo "Output directory    : $OUTPUT_DIR"
echo "============================================================"
echo "Artifacts:"
find "$OUTPUT_DIR" \
    -maxdepth 1 \
    -type f \
    -printf '  %f\n' |
    sort
echo "============================================================"
