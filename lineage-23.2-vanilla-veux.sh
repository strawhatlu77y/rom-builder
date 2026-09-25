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
#   branch lineage: 16-qpr2
#   pinned commit:
#   30e3b032c8f27780f6011bc61c4c4b655985c9bb
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
#   Vanilla build. No GApps, MindTheGapps, NikGapps, BitGApps,
#   OpenGApps, MiuiCamera, Dolby, ViPER4Android, or old 22.1
#   audio/BootControl hacks are injected by this script.
# ============================================================

ROM_BRANCH="${ROM_BRANCH:-lineage-23.2}"
SOURCE_MANIFEST="${SOURCE_MANIFEST:-https://github.com/accupara/los23.2.git}"
KERNEL_COMMIT="${KERNEL_COMMIT:-30e3b032c8f27780f6011bc61c4c4b655985c9bb}"
SOURCE_ROOT="${SOURCE_ROOT:-$PWD}"
OUTPUT_DIR="${OUTPUT_DIR:-$SOURCE_ROOT/imgs_output}"
PREFLIGHT_ONLY="${PREFLIGHT_ONLY:-0}"
EXTRACT_BLOBS="${EXTRACT_BLOBS:-none}"
BLOB_SOURCE="${BLOB_SOURCE:-}"
REPO_JOBS="${REPO_JOBS:-8}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
DEVICE="veux"
PRODUCT="lineage_veux"
RELEASE="trunk_staging"
EXPECTED_PRODUCT_NAME="lineage_veux"
EXPECTED_KERNEL_CONFIG="veux_defconfig"
EXPECTED_KERNEL_PATH="kernel/xiaomi/sm6375"
EXPECTED_DEVICE_PATH="device/xiaomi/veux"
EXPECTED_COMMON_PATH="device/xiaomi/sm6375-common"
EXPECTED_VENDOR_PATH="vendor/xiaomi/veux"
EXPECTED_HARDWARE_PATH="hardware/xiaomi"

log()  { printf '\n[%s] %s\n' "INFO" "$*"; }
warn() { printf '\n[%s] %s\n' "WARN" "$*" >&2; }
die()  { printf '\n[%s] %s\n' "ERROR" "$*" >&2; exit 1; }

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

command -v git >/dev/null 2>&1 || die "git is missing"
command -v repo >/dev/null 2>&1 || die "repo is missing"
command -v python3 >/dev/null 2>&1 || die "python3 is missing"
command -v java >/dev/null 2>&1 || die "java is missing"
command -v sed >/dev/null 2>&1 || die "sed is missing"
command -v grep >/dev/null 2>&1 || die "grep is missing"
command -v find >/dev/null 2>&1 || die "find is missing"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is missing"

if [ -x /opt/crave/resync.sh ]; then
    log "Crave resync helper detected"
else
    warn "/opt/crave/resync.sh not found in current environment"
    warn "This script is intended to be run inside a Crave build environment"
fi

git --version
repo --version | head -n 1 || true
python3 --version
java -version 2>&1 | head -n 1

# ============================================================
# 2. Initialize / refresh source tree
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

    <!-- Xiaomi hardware -->
    <project
        name="LineageOS/android_hardware_xiaomi"
        path="hardware/xiaomi"
        revision="lineage-23.2"
        clone-depth="1" />

    <!-- Qualcomm A/B BootControl used by the current SM6375 common tree -->
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
    repo sync -c --force-sync --no-clone-bundle --no-tags -j"$REPO_JOBS"
fi

# ============================================================
# 5. Source validation
# ============================================================

log "Validating required repositories"

for dir in \
    "$EXPECTED_DEVICE_PATH" \
    "$EXPECTED_COMMON_PATH" \
    "$EXPECTED_HARDWARE_PATH" \
    "$EXPECTED_KERNEL_PATH" \
    "$EXPECTED_VENDOR_PATH" \
    "vendor/xiaomi/sm6375-common" \
    "hardware/qcom-caf/bootctrl" \
    "hardware/qcom-caf/common/libqti-perfd-client" \
    "hardware/qcom-caf/sm8350" \
    "vendor/qcom/opensource/display"
do
    [ -d "$dir" ] || die "Missing required directory: $dir"
done

git -C "$EXPECTED_DEVICE_PATH" rev-parse --show-toplevel >/dev/null
git -C "$EXPECTED_COMMON_PATH" rev-parse --show-toplevel >/dev/null
git -C "$EXPECTED_HARDWARE_PATH" rev-parse --show-toplevel >/dev/null
git -C "$EXPECTED_KERNEL_PATH" rev-parse --show-toplevel >/dev/null
git -C "$EXPECTED_VENDOR_PATH" rev-parse --show-toplevel >/dev/null
git -C "vendor/xiaomi/sm6375-common" rev-parse --show-toplevel >/dev/null

log "Source repositories present"

[ -f hardware/qcom-caf/bootctrl/aidl/Android.bp ] || die "QTI BootControl Android.bp missing"
[ -f hardware/qcom-caf/bootctrl/aidl/BootControl.cpp ] || die "QTI BootControl implementation missing"
[ -f hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt ] || die "Holi audio_tuning_mixer.txt missing"
[ -f hardware/qcom-caf/sm8350/audio/configs/holi/audio_effects.xml ] || die "Holi audio_effects.xml missing"

# ============================================================
# 6. Kernel validation
# ============================================================

log "Validating kernel"

ACTUAL_KERNEL_COMMIT="$(git -C "$EXPECTED_KERNEL_PATH" rev-parse HEAD)"
echo "Expected kernel commit: $KERNEL_COMMIT"
echo "Actual kernel commit:   $ACTUAL_KERNEL_COMMIT"

[ "$ACTUAL_KERNEL_COMMIT" = "$KERNEL_COMMIT" ] || \
    die "Kernel commit mismatch"

[ -f "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" ] || \
    die "$EXPECTED_KERNEL_CONFIG not found"

grep -q 'CONFIG_QGKI=y' \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" || \
    die "Kernel config does not contain CONFIG_QGKI=y"

log "Kernel validated"

# ============================================================
# 7. Device-tree / build metadata validation
# ============================================================

log "Validating VEUX product definition"

[ -f "$EXPECTED_DEVICE_PATH/AndroidProducts.mk" ] || die "AndroidProducts.mk missing"
[ -f "$EXPECTED_DEVICE_PATH/BoardConfig.mk" ] || die "BoardConfig.mk missing"
[ -f "$EXPECTED_DEVICE_PATH/device.mk" ] || die "device.mk missing"
[ -f "$EXPECTED_DEVICE_PATH/lineage_veux.mk" ] || die "lineage_veux.mk missing"

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

# ============================================================
# 8. Dependency validation
# ============================================================

log "Validating device dependencies"

grep -q 'android_device_xiaomi_sm6375-common' \
    "$EXPECTED_DEVICE_PATH/lineage.dependencies" || \
    die "VEUX lineage.dependencies does not reference SM6375 common"

grep -q 'android_hardware_xiaomi' \
    "$EXPECTED_COMMON_PATH/lineage.dependencies" || \
    die "Common lineage.dependencies does not reference Xiaomi hardware"

grep -q 'android_kernel_xiaomi_sm6375' \
    "$EXPECTED_COMMON_PATH/lineage.dependencies" || \
    die "Common lineage.dependencies does not reference SM6375 kernel"

# ============================================================
# 9. Proprietary source validation
# ============================================================

log "Validating proprietary-file manifests"

[ -f "$EXPECTED_DEVICE_PATH/proprietary-files.txt" ] || \
    die "VEUX proprietary-files.txt missing"

NONCOMMENT_BLOB_COUNT="$(
    grep -v '^[[:space:]]*$' "$EXPECTED_DEVICE_PATH/proprietary-files.txt" |
    grep -v '^[[:space:]]*#' |
    wc -l
)"

[ "$NONCOMMENT_BLOB_COUNT" -gt 0 ] || \
    die "VEUX proprietary-files.txt appears empty"

log "VEUX proprietary entries: $NONCOMMENT_BLOB_COUNT"

# Keep extraction optional. The source tree already has vendor projects
# and device extraction metadata; this is only for rebuilding vendors
# when the user deliberately requests it.
case "$EXTRACT_BLOBS" in
    none)
        ;;
    adb)
        command -v adb >/dev/null 2>&1 || die "adb is required for EXTRACT_BLOBS=adb"
        [ -f "$EXPECTED_DEVICE_PATH/extract-files.py" ] || die "extract-files.py is missing"
        (
            cd "$EXPECTED_DEVICE_PATH"
            PYTHONPATH=../../../tools/extract-utils python3 ./extract-files.py
        )
        ;;
    dump)
        [ -n "$BLOB_SOURCE" ] || die "BLOB_SOURCE is required for EXTRACT_BLOBS=dump"
        [ -d "$BLOB_SOURCE" ] || die "BLOB_SOURCE directory does not exist: $BLOB_SOURCE"
        BLOB_SOURCE="$(cd "$BLOB_SOURCE" && pwd -P)"
        [ -f "$EXPECTED_DEVICE_PATH/extract-files.py" ] || die "extract-files.py is missing"
        (
            cd "$EXPECTED_DEVICE_PATH"
            PYTHONPATH=../../../tools/extract-utils python3 ./extract-files.py "$BLOB_SOURCE"
        )
        ;;
    *)
        die "EXTRACT_BLOBS must be none, adb, or dump"
        ;;
esac

# ============================================================
# 10. Do NOT carry over 22.1-era patches
# ============================================================

log "Checking that obsolete 22.1 customizations are not being injected"

# These are intentionally not modified:
#   device.mk bootctrl entries
#   BoardConfig BOARD_OPENSOURCE_DIR
#   QTI gpt-utils source
#   old Holi audio config repository
#   MIUI Camera removal
#   Dolby removal
#   ViPER4Android removal
#   XiaomiParts injection
#   GApps / WITH_GMS
#
# The 23.2 tree is used as authored by its current maintainers.

if grep -RInE \
    'MindTheGapps|vendor/gapps|WITH_GMS *: *= *true|NikGapps|BitGApps|OpenGApps' \
    "$EXPECTED_DEVICE_PATH" \
    "$EXPECTED_COMMON_PATH" \
    2>/dev/null
then
    die "GApps references unexpectedly found in device/common source"
fi

# ============================================================
# 11. Environment fixes that are generally safe for build
# ============================================================

export BUILD_USERNAME="${BUILD_USERNAME:-crave}"
export BUILD_HOSTNAME="${BUILD_HOSTNAME:-foss}"

# Missing required modules can be a legitimate source-tree transition
# issue on Crave. Keep the proven workaround configurable rather than
# patching Android source files.
export BUILD_BROKEN_MISSING_REQUIRED_MODULES="${BUILD_BROKEN_MISSING_REQUIRED_MODULES:-true}"

# ============================================================
# 12. Build environment setup
# ============================================================

log "Loading build environment"

set +u
source build/envsetup.sh
lunch "$PRODUCT" "$RELEASE" "userdebug"
set -u

# ============================================================
# 13. Product resolution checks
# ============================================================

log "Checking resolved build variables"

TARGET_PRODUCT_RESOLVED="$(get_build_var TARGET_PRODUCT)"
TARGET_BUILD_VARIANT_RESOLVED="$(get_build_var TARGET_BUILD_VARIANT)"
TARGET_DEVICE_RESOLVED="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH_RESOLVED="$(get_build_var TARGET_ARCH)"
TARGET_KERNEL_SOURCE_RESOLVED="$(get_build_var TARGET_KERNEL_SOURCE)"
TARGET_KERNEL_CONFIG_RESOLVED="$(get_build_var TARGET_KERNEL_CONFIG)"
PRODUCT_OUT_RESOLVED="$(get_build_var PRODUCT_OUT)"
DYNAMIC_PARTITIONS_RESOLVED="$(get_build_var PRODUCT_USE_DYNAMIC_PARTITIONS)"
PRODUCT_PACKAGES_RESOLVED="$(get_build_var PRODUCT_PACKAGES)"

echo "TARGET_PRODUCT=${TARGET_PRODUCT_RESOLVED}"
echo "TARGET_BUILD_VARIANT=${TARGET_BUILD_VARIANT_RESOLVED}"
echo "TARGET_DEVICE=${TARGET_DEVICE_RESOLVED}"
echo "TARGET_ARCH=${TARGET_ARCH_RESOLVED}"
echo "TARGET_KERNEL_SOURCE=${TARGET_KERNEL_SOURCE_RESOLVED}"
echo "TARGET_KERNEL_CONFIG=${TARGET_KERNEL_CONFIG_RESOLVED}"
echo "PRODUCT_OUT=${PRODUCT_OUT_RESOLVED}"
echo "PRODUCT_USE_DYNAMIC_PARTITIONS=${DYNAMIC_PARTITIONS_RESOLVED}"

[ "$TARGET_PRODUCT_RESOLVED" = "$EXPECTED_PRODUCT_NAME" ] || die "TARGET_PRODUCT mismatch"
[ "$TARGET_DEVICE_RESOLVED" = "$DEVICE" ] || die "TARGET_DEVICE mismatch"
[ "$TARGET_ARCH_RESOLVED" = "arm64" ] || die "TARGET_ARCH mismatch"
[ "$TARGET_KERNEL_SOURCE_RESOLVED" = "$EXPECTED_KERNEL_PATH" ] || die "TARGET_KERNEL_SOURCE mismatch"
[[ "$TARGET_KERNEL_CONFIG_RESOLVED" == *"$EXPECTED_KERNEL_CONFIG"* ]] || die "veux_defconfig was not resolved"
[ "$DYNAMIC_PARTITIONS_RESOLVED" = "true" ] || die "Dynamic partitions were not enabled"
[ -n "$PRODUCT_OUT_RESOLVED" ] || die "PRODUCT_OUT is empty"

has_package() {
    local wanted="$1"
    awk -v wanted="$wanted" '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == wanted) found = 1
            }
        }
        END { exit(found ? 0 : 1) }
    ' <<< "$PRODUCT_PACKAGES_RESOLVED"
}

for package in     android.hardware.boot-service.qti     android.hardware.boot-service.qti.recovery     fastbootd
do
    has_package "$package" || die "Required resolved package missing: $package"
done

TARGET_PRODUCT="$TARGET_PRODUCT_RESOLVED"
TARGET_BUILD_VARIANT="$TARGET_BUILD_VARIANT_RESOLVED"
TARGET_DEVICE="$TARGET_DEVICE_RESOLVED"
TARGET_ARCH="$TARGET_ARCH_RESOLVED"
TARGET_KERNEL_SOURCE="$TARGET_KERNEL_SOURCE_RESOLVED"
TARGET_KERNEL_CONFIG="$TARGET_KERNEL_CONFIG_RESOLVED"
PRODUCT_OUT="$PRODUCT_OUT_RESOLVED"

# ============================================================
# 14. Kernel output config sanity
# ============================================================

log "Checking kernel configuration prerequisites"

grep -q 'CONFIG_WT_QGKI=y' \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" || \
    die "Kernel config missing CONFIG_WT_QGKI=y"

grep -q 'CONFIG_LTO_CLANG=y' \
    "$EXPECTED_KERNEL_PATH/arch/arm64/configs/$EXPECTED_KERNEL_CONFIG" || \
    die "Kernel config missing CONFIG_LTO_CLANG=y"

# ============================================================
# 15. Preflight-only mode
# ============================================================

if [ "$PREFLIGHT_ONLY" = "1" ]; then
    log "PREFLIGHT_ONLY=1"
    echo
    echo "============================================================"
    echo " PREFLIGHT PASSED"
    echo "============================================================"
    echo "Product : $TARGET_PRODUCT"
    echo "Device  : $TARGET_DEVICE"
    echo "Kernel  : $ACTUAL_KERNEL_COMMIT"
    echo "Config  : $EXPECTED_KERNEL_CONFIG"
    echo "Variant : $TARGET_BUILD_VARIANT"
    echo "============================================================"
    exit 0
fi

# ============================================================
# 16. Small, targeted pre-build checks
# ============================================================

log "Running targeted pre-build checks"

# Resolve boot control / fastboot modules without changing source files.
m libgptutils.qti -j"$BUILD_JOBS"

# ============================================================
# 17. Full build
# ============================================================

log "Starting LineageOS 23.2 Vanilla build"

mka -j"$BUILD_JOBS" bacon

# ============================================================
# 18. Collect build artifacts
# ============================================================

log "Collecting artifacts"

[ -d "$PRODUCT_OUT" ] || die "Product output directory missing: $PRODUCT_OUT"

mkdir -p "$OUTPUT_DIR"

for img in \
    boot.img \
    dtbo.img \
    recovery.img \
    super.img \
    vendor_boot.img \
    vbmeta.img \
    vbmeta_system.img
do
    if [ -f "$PRODUCT_OUT/$img" ]; then
        cp -f "$PRODUCT_OUT/$img" "$OUTPUT_DIR/"
    fi
done

shopt -s nullglob
ZIP_ARTIFACTS=( "$PRODUCT_OUT"/lineage-*.zip )
if (( ${#ZIP_ARTIFACTS[@]} == 0 )); then
    die "Build completed but no LineageOS ZIP was found in $PRODUCT_OUT"
fi
cp -f -- "${ZIP_ARTIFACTS[@]}" "$OUTPUT_DIR/"

for checksum in     "$PRODUCT_OUT"/lineage-*.zip.md5sum     "$PRODUCT_OUT"/lineage-*.zip.sha256sum
do
    [ -f "$checksum" ] && cp -f "$checksum" "$OUTPUT_DIR/" || true
done
shopt -u nullglob

# Copy useful metadata when present.
for file in \
    "$PRODUCT_OUT/installed-files.txt" \
    "$PRODUCT_OUT/obj/PACKAGING/target_files_intermediates"/*.zip
do
    [ -f "$file" ] && cp -f "$file" "$OUTPUT_DIR/" || true
done

# ============================================================
# 19. Checksums
# ============================================================

log "SHA256 checksums"

(
    cd "$OUTPUT_DIR"
    find . -maxdepth 1 -type f -print0 |
        sort -z |
        xargs -0 -r sha256sum
) | tee "$OUTPUT_DIR/SHA256SUMS.txt"

# ============================================================
# 20. Final report
# ============================================================

echo
echo "============================================================"
echo " BUILD FINISHED"
echo "============================================================"
echo "ROM branch          : $ROM_BRANCH"
echo "Product             : $TARGET_PRODUCT"
echo "Device              : $TARGET_DEVICE"
echo "Kernel              : CaesiumOS/kernel_xiaomi_sm6375"
echo "Kernel commit       : $ACTUAL_KERNEL_COMMIT"
echo "Kernel config       : $EXPECTED_KERNEL_CONFIG"
echo "Build variant       : $TARGET_BUILD_VARIANT"
echo "Output directory    : $OUTPUT_DIR"
echo "============================================================"
echo "ZIP / image artifacts:"
find "$OUTPUT_DIR" -maxdepth 1 -type f -printf '%f\n' | sort || true
echo "============================================================"
