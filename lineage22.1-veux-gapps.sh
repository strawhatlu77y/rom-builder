#!/bin/bash
set -e

###############################################################################
# LineageOS 22.1 + MindTheGapps
# Xiaomi VEUX / PEUX
#
# Device:
#   Redmi Note 11 Pro+ 5G
#   POCO X4 Pro 5G
#
# Android:
#   Android 15
#   LineageOS 22.1
#
# GApps:
#   MindTheGapps 15.0.0 ARM64
#   Release: 20260915_032013
#   Source commit:
#   e14b22768c60978d0e1267dab5bcf62dfcc73d16
#
# IMPORTANT:
# This script is designed to be executed with:
#
#   crave run --no-patch -- "bash lineage22.1-veux-gapps.sh"
#
# or through the GitHub raw URL.
###############################################################################

set -o pipefail

###############################################################################
# BUILD ENVIRONMENT
###############################################################################

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

###############################################################################
# PATHS
###############################################################################

DEVICE_PATH="device/xiaomi/veux"
BOOTCTRL_PATH="hardware/qcom-caf/bootctrl"
GAPPS_PATH="vendor/gapps"

GAPPS_COMMIT="e14b22768c60978d0e1267dab5bcf62dfcc73d16"

###############################################################################
# HELPER FUNCTIONS
###############################################################################

die() {
    echo
    echo "============================================================"
    echo " ERROR"
    echo "============================================================"
    echo "$1"
    exit 1
}

section() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

###############################################################################
# CHECK WORKING DIRECTORY
###############################################################################

section "CHECKING BUILD DIRECTORY"

echo "Current directory:"
pwd

if [ ! -d ".repo" ]; then
    echo "No existing Lineage source detected."
    echo "repo init will create the source tree."
fi

###############################################################################
# CLEAN LOCAL MANIFESTS
###############################################################################

section "CLEANING LOCAL MANIFESTS"

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

###############################################################################
# INITIALIZE LINEAGEOS 22.1
###############################################################################

section "INITIALIZING LINEAGEOS 22.1"

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1

###############################################################################
# CREATE LOCAL MANIFEST
###############################################################################

section "CREATING VEUX + MINDTHEGAPPS MANIFEST"

cat > .repo/local_manifests/veux.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>

<manifest>

    <!-- ========================================================= -->
    <!-- Xiaomi VEUX device tree                                   -->
    <!-- ========================================================= -->

    <project
        name="Amrito-Projects/device_xiaomi_veux"
        path="device/xiaomi/veux"
        revision="15"
        depth="1" />

    <!-- ========================================================= -->
    <!-- Xiaomi proprietary vendor                                 -->
    <!-- ========================================================= -->

    <project
        name="Amrito-Projects/vendor_xiaomi_veux-new"
        path="vendor/xiaomi/veux"
        revision="15"
        depth="1" />

    <!-- ========================================================= -->
    <!-- Kernel                                                     -->
    <!-- ========================================================= -->

    <project
        name="dereference23/kernel_xiaomi_sm6375"
        path="kernel/xiaomi/veux"
        revision="main"
        depth="1" />

    <!-- ========================================================= -->
    <!-- Xiaomi hardware                                             -->
    <!-- ========================================================= -->

    <project
        name="LineageOS/android_hardware_xiaomi"
        path="hardware/xiaomi"
        revision="lineage-22.1"
        depth="1" />

    <!-- ========================================================= -->
    <!-- Holi audio configuration                                   -->
    <!-- ========================================================= -->

    <project
        name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi"
        path="hardware/qcom-caf/sm8350/audio/configs/holi"
        revision="14"
        depth="1" />

    <!-- ========================================================= -->
    <!-- MindTheGapps Android 15                                    -->
    <!-- Exact release source commit                               -->
    <!-- ========================================================= -->

    <remote
        name="mindthegapps"
        fetch="https://gitlab.com/MindTheGapps/" />

    <project
        name="vendor_gapps"
        path="vendor/gapps"
        remote="mindthegapps"
        revision="${GAPPS_COMMIT}" />

</manifest>
EOF

###############################################################################
# RESYNC SOURCE
###############################################################################

section "RESYNCING SOURCE WITH CRAVE"

echo "Using /opt/crave/resync.sh"
echo "This may take some time."

/opt/crave/resync.sh

###############################################################################
# VERIFY REQUIRED DIRECTORIES
###############################################################################

section "VERIFYING REQUIRED REPOSITORIES"

REQUIRED_DIRS=(
    "$DEVICE_PATH"
    "vendor/xiaomi/veux"
    "kernel/xiaomi/veux"
    "hardware/xiaomi"
    "hardware/qcom-caf/sm8350/audio/configs/holi"
    "$BOOTCTRL_PATH"
    "$GAPPS_PATH"
)

for DIR in "${REQUIRED_DIRS[@]}"; do

    if [ ! -d "$DIR" ]; then
        die "Required directory missing: $DIR"
    fi

    echo "OK: $DIR"

done

###############################################################################
# VERIFY MINDTHEGAPPS
###############################################################################

section "VERIFYING MINDTHEGAPPS"

if [ ! -f "$GAPPS_PATH/arm64/arm64-vendor.mk" ]; then
    die "MindTheGapps arm64-vendor.mk was not found."
fi

echo "MindTheGapps makefile found."

###############################################################################
# VERIFY EXACT GAPPS COMMIT
###############################################################################

if git -C "$GAPPS_PATH" rev-parse HEAD >/dev/null 2>&1; then

    ACTUAL_GAPPS_COMMIT="$(git -C "$GAPPS_PATH" rev-parse HEAD)"

    echo "Expected GApps commit:"
    echo "$GAPPS_COMMIT"

    echo "Actual GApps commit:"
    echo "$ACTUAL_GAPPS_COMMIT"

    if [ "$ACTUAL_GAPPS_COMMIT" != "$GAPPS_COMMIT" ]; then
        die "MindTheGapps commit mismatch."
    fi

    echo "MindTheGapps commit verified."

else
    die "Unable to determine MindTheGapps Git commit."
fi

###############################################################################
# REMOVE OBSOLETE VENDORSETUP
###############################################################################

section "REMOVING OBSOLETE VENDORSETUP"

rm -f "$DEVICE_PATH/vendorsetup.sh"

echo "vendorsetup.sh removed if it existed."

###############################################################################
# REMOVE CUSTOM MIUI CAMERA / DOLBY / VIPER REFERENCES
###############################################################################

section "REMOVING MIUI CAMERA / DOLBY / VIPER"

DEVICE_MK="$DEVICE_PATH/device.mk"

[ -f "$DEVICE_MK" ] || die "device.mk not found."

###############################################################################
# MIUI CAMERA
###############################################################################

sed -i \
    '/vendor\/xiaomi\/miuicamera-veux\/MiuiCamera-veux.mk/d' \
    "$DEVICE_MK"

###############################################################################
# VIPER4ANDROID
###############################################################################

sed -i \
    '/packages\/apps\/ViPER4AndroidFX\/config.mk/d' \
    "$DEVICE_MK"

###############################################################################
# DOLBY
###############################################################################

sed -i \
    '/vendor\/sony\/dolby\/setup.mk/d' \
    "$DEVICE_MK"

###############################################################################
# REMOVE OLD COMMENTS
###############################################################################

sed -i '/^# MiuiCamera$/d' "$DEVICE_MK"
sed -i '/^# Viper4AndroidFX$/d' "$DEVICE_MK"
sed -i '/^# Dolby$/d' "$DEVICE_MK"

###############################################################################
# REMOVE MIUI CAMERA SEPOLICY REFERENCE
###############################################################################

section "REMOVING MIUI CAMERA SEPOLICY"

BOARD_CONFIG="$DEVICE_PATH/BoardConfig.mk"

[ -f "$BOARD_CONFIG" ] || die "BoardConfig.mk not found."

sed -i \
    '/vendor\/xiaomi\/miuicamera-veux\/SEPolicy-veux.mk/d' \
    "$BOARD_CONFIG"

###############################################################################
# DISABLE QCOM DOLBY DAP
###############################################################################

section "DISABLING DOLBY DAP"

if grep -q '^AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP' "$BOARD_CONFIG"; then

    sed -i \
        's/^AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP.*/AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP := false/' \
        "$BOARD_CONFIG"

else

    printf '\nAUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP := false\n' \
        >> "$BOARD_CONFIG"

fi

echo "Dolby DAP disabled."

###############################################################################
# REMOVE RemovePackagesVeux
###############################################################################

section "REMOVING RemovePackagesVeux"

rm -rf "$DEVICE_PATH/RemovePackages"

sed -i '/RemovePackagesVeux/d' "$DEVICE_MK"
sed -i '/^# Remove unwanted packages$/d' "$DEVICE_MK"

###############################################################################
# BOOT CONTROL FIX
###############################################################################

section "APPLYING QTI BOOT CONTROL FIX"

AIDL_BP="$BOOTCTRL_PATH/aidl/Android.bp"

[ -f "$AIDL_BP" ] || die "Missing bootctrl Android.bp."

###############################################################################
# Add normal QTI boot service
###############################################################################

if ! grep -q 'name: "android.hardware.boot-service.qti",' "$AIDL_BP"; then

cat >> "$AIDL_BP" <<'EOF'

cc_binary {
    name: "android.hardware.boot-service.qti",
    defaults: ["android.hardware.boot-service.qti_defaults"],
    static_libs: ["libgptutils.qti"],
}
EOF

fi

###############################################################################
# Add recovery QTI boot service
###############################################################################

if ! grep -q 'name: "android.hardware.boot-service.qti.recovery",' "$AIDL_BP"; then

cat >> "$AIDL_BP" <<'EOF'

cc_binary {
    name: "android.hardware.boot-service.qti.recovery",
    defaults: ["android.hardware.boot-service.qti.recovery_defaults"],
    static_libs: ["libgptutils.qti"],
}
EOF

fi

###############################################################################
# GPT UTILS FIX
#
# Original problem:
#
# fatal error:
# 'scsi/ufs/ioctl.h' file not found
#
# Successful build used:
#
# -D_BSG_FRAMEWORK_KERNEL_HEADERS
###############################################################################

section "APPLYING GPT UTILS HEADER FIX"

GPT_BP="$BOOTCTRL_PATH/gpt-utils/Android.bp"

[ -f "$GPT_BP" ] || die "Missing GPT Utils Android.bp."

if grep -q 'false: \[\]' "$GPT_BP"; then

    sed -i \
        's/false: \[\]/false: ["-D_BSG_FRAMEWORK_KERNEL_HEADERS"]/' \
        "$GPT_BP"

elif ! grep -q '_BSG_FRAMEWORK_KERNEL_HEADERS' "$GPT_BP"; then

    die "Unable to apply GPT Utils header fix automatically."

fi

###############################################################################
# BOARD_OPENSOURCE_DIR FIX
###############################################################################

section "APPLYING BOARD_OPENSOURCE_DIR FIX"

if ! grep -q '^BOARD_OPENSOURCE_DIR' "$BOARD_CONFIG"; then
    printf '\nBOARD_OPENSOURCE_DIR :=\n' >> "$BOARD_CONFIG"
fi

echo "BOARD_OPENSOURCE_DIR is defined."

###############################################################################
# VERIFY AUDIO CONFIGURATION
###############################################################################

section "VERIFYING AUDIO CONFIGURATION"

if ! grep -q 'audio.primary.holi' "$DEVICE_MK"; then
    die "audio.primary.holi is missing from device.mk."
fi

if ! grep -q 'audio_tuning_mixer.txt' "$DEVICE_MK"; then
    die "audio_tuning_mixer.txt is missing from device.mk."
fi

if [ ! -d "hardware/qcom-caf/sm8350/audio/configs/holi" ]; then
    die "Holi audio configuration directory missing."
fi

echo "Qualcomm Holi audio configuration verified."

###############################################################################
# VERIFY AUDIO HAL PACKAGES
###############################################################################

for AUDIO_MODULE in \
    audio.primary.holi \
    audio.bluetooth.default \
    audio.r_submix.default \
    audio.usb.default
do

    if ! grep -q "$AUDIO_MODULE" "$DEVICE_MK"; then
        die "Required audio module missing: $AUDIO_MODULE"
    fi

done

echo "Required audio modules verified."

###############################################################################
# VERIFY BOOT CONTROL PACKAGES
###############################################################################

section "VERIFYING BOOT CONTROL"

if ! grep -q 'android.hardware.boot-service.qti' "$DEVICE_MK"; then
    die "QTI boot service missing from device.mk."
fi

if ! grep -q 'android.hardware.boot-service.qti.recovery' "$DEVICE_MK"; then
    die "QTI recovery boot service missing from device.mk."
fi

if ! grep -q 'name: "android.hardware.boot-service.qti"' "$AIDL_BP"; then
    die "QTI boot service binary missing."
fi

if ! grep -q 'name: "android.hardware.boot-service.qti.recovery"' "$AIDL_BP"; then
    die "QTI recovery boot service binary missing."
fi

echo "Boot control configuration verified."

###############################################################################
# GMS CONFIGURATION
###############################################################################

section "ENABLING GMS"

LINEAGE_MK="$DEVICE_PATH/lineage_veux.mk"

[ -f "$LINEAGE_MK" ] || die "lineage_veux.mk not found."

###############################################################################
# WITH_GMS
###############################################################################

if grep -q '^WITH_GMS' "$LINEAGE_MK"; then

    sed -i \
        's/^WITH_GMS.*/WITH_GMS := true/' \
        "$LINEAGE_MK"

else

    cat >> "$LINEAGE_MK" <<'EOF'

WITH_GMS := true
EOF

fi

###############################################################################
# Ensure MindTheGapps is inherited
###############################################################################

if ! grep -q 'vendor/gapps/arm64/arm64-vendor.mk' "$LINEAGE_MK"; then

cat >> "$LINEAGE_MK" <<'EOF'

###############################################################################
# MindTheGapps Android 15 ARM64
###############################################################################

$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
EOF

fi

###############################################################################
# OPTIONAL PACKAGE REMOVAL
#
# These are explicitly requested to be removed.
#
# XiaomiParts is NOT removed.
###############################################################################

section "CONFIGURING OPTIONAL PACKAGE REMOVALS"

if ! grep -q '# VEUX optional package removals' "$LINEAGE_MK"; then

cat >> "$LINEAGE_MK" <<'EOF'

###############################################################################
# VEUX optional package removals
###############################################################################

PRODUCT_PACKAGES := $(filter-out \
    Seedvault \
    ThemePicker \
    Updater \
    QuickAccessWallet, \
    $(PRODUCT_PACKAGES))

EOF

fi

###############################################################################
# VERIFY XIAOMIPARTS IS STILL ENABLED
###############################################################################

section "VERIFYING XIAOMIPARTS"

if grep -q 'XiaomiParts' "$DEVICE_MK"; then
    echo "XiaomiParts: KEEP"
else
    die "XiaomiParts was unexpectedly removed."
fi

###############################################################################
# VERIFY REMOVED REPOSITORIES / REFERENCES
###############################################################################

section "VERIFYING REMOVED COMPONENTS"

###############################################################################
# Device tree references
###############################################################################

BAD_REFS="$(
    grep -RInE \
        'miuicamera|MiuiCamera|vendor/sony/dolby|ViPER4AndroidFX|RemovePackagesVeux' \
        "$DEVICE_PATH" \
        2>/dev/null || true
)"

if [ -n "$BAD_REFS" ]; then

    echo "Found forbidden references:"
    echo "$BAD_REFS"

    die "Removed components are still referenced."

fi

echo "MIUI Camera references: CLEAN"
echo "Dolby repository references: CLEAN"
echo "ViPER4AndroidFX references: CLEAN"
echo "RemovePackagesVeux references: CLEAN"

###############################################################################
# Verify repositories themselves are absent
###############################################################################

if [ -e "vendor/xiaomi/miuicamera-veux" ]; then
    die "vendor/xiaomi/miuicamera-veux still exists."
fi

if [ -e "vendor/xiaomi/miuicamera" ]; then
    die "vendor/xiaomi/miuicamera still exists."
fi

if [ -e "vendor/sony/dolby" ]; then
    die "vendor/sony/dolby still exists."
fi

if [ -e "packages/apps/ViPER4AndroidFX" ]; then
    die "packages/apps/ViPER4AndroidFX still exists."
fi

echo "MIUI Camera repository: ABSENT"
echo "Dolby repository: ABSENT"
echo "ViPER4AndroidFX repository: ABSENT"

###############################################################################
# VERIFY OPTIONAL PACKAGE FILTER
###############################################################################

section "VERIFYING OPTIONAL PACKAGE FILTER"

for PACKAGE in \
    Seedvault \
    ThemePicker \
    Updater \
    QuickAccessWallet
do

    if ! grep -q "$PACKAGE" "$LINEAGE_MK"; then
        die "$PACKAGE filter missing from lineage_veux.mk."
    fi

done

echo "Seedvault filter: OK"
echo "ThemePicker filter: OK"
echo "Updater filter: OK"
echo "QuickAccessWallet filter: OK"

###############################################################################
# VERIFY GMS
###############################################################################

section "VERIFYING GMS CONFIGURATION"

if ! grep -q '^WITH_GMS := true' "$LINEAGE_MK"; then
    die "WITH_GMS is not enabled."
fi

if ! grep -q 'vendor/gapps/arm64/arm64-vendor.mk' "$LINEAGE_MK"; then
    die "MindTheGapps inheritance is missing."
fi

echo "WITH_GMS=true"
echo "MindTheGapps ARM64 makefile included."

###############################################################################
# CHECK BOARD RESERVED SPACE
###############################################################################

section "CHECKING GMS PARTITION RESERVED SPACE"

if grep -q 'BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 25165824' "$BOARD_CONFIG"; then
    echo "System reserved size: 24 MiB"
else
    echo "WARNING: Expected 24 MiB system reserved size not found."
fi

if grep -q 'BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE := 25165824' "$BOARD_CONFIG"; then
    echo "System_ext reserved size: 24 MiB"
else
    echo "WARNING: Expected 24 MiB system_ext reserved size not found."
fi

if grep -q 'BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 25165824' "$BOARD_CONFIG"; then
    echo "Product reserved size: 24 MiB"
else
    echo "WARNING: Expected 24 MiB product reserved size not found."
fi

###############################################################################
# PRINT FINAL IMPORTANT SETTINGS
###############################################################################

section "FINAL CONFIGURATION"

echo
echo "Device:"
echo "  Redmi Note 11 Pro+ 5G / POCO X4 Pro 5G"
echo
echo "Target:"
echo "  lineage_veux"
echo
echo "Lineage:"
echo "  22.1 / Android 15"
echo
echo "Architecture:"
echo "  arm64"
echo
echo "GApps:"
echo "  MindTheGapps 15.0.0 ARM64"
echo "  Commit: $GAPPS_COMMIT"
echo
echo "Removed:"
echo "  MIUI Camera"
echo "  Dolby"
echo "  ViPER4AndroidFX"
echo "  Seedvault"
echo "  ThemePicker"
echo "  Updater"
echo "  QuickAccessWallet"
echo "  RemovePackagesVeux"
echo
echo "Kept:"
echo "  XiaomiParts"
echo "  LineageParts"
echo "  Qualcomm audio HAL"
echo "  Holi audio configuration"
echo
echo "Successful fixes:"
echo "  QTI boot service"
echo "  QTI recovery boot service"
echo "  GPT Utils BSG headers"
echo "  BOARD_OPENSOURCE_DIR"
echo "  BUILD_BROKEN_MISSING_REQUIRED_MODULES"
echo

###############################################################################
# SOURCE ENVIRONMENT
###############################################################################

section "INITIALIZING BUILD ENVIRONMENT"

source build/envsetup.sh

###############################################################################
# SELECT DEVICE
###############################################################################

section "SELECTING VEUX"

breakfast veux

###############################################################################
# GPT PREFLIGHT
###############################################################################

section "GPT UTILS PREFLIGHT"

echo
echo "Building libgptutils.qti before the full ROM."
echo "If this fails, the full build will stop."

m libgptutils.qti -j"$(nproc)"

echo
echo "GPT PREFLIGHT PASSED."

###############################################################################
# FULL BUILD
###############################################################################

section "STARTING FULL LINEAGEOS 22.1 + GAPPS BUILD"

echo
echo "This is the expensive step."
echo "Starting mka bacon..."
echo

mka bacon

###############################################################################
# BUILD OUTPUT
###############################################################################

section "COLLECTING BUILD OUTPUT"

PRODUCT_OUT="out/target/product/veux"

mkdir -p imgs_output

###############################################################################
# Copy important images
###############################################################################

for FILE in \
    boot.img \
    dtbo.img \
    vendor_boot.img \
    recovery.img \
    vbmeta.img \
    vbmeta_system.img
do

    if [ -f "$PRODUCT_OUT/$FILE" ]; then

        cp -f \
            "$PRODUCT_OUT/$FILE" \
            "imgs_output/$FILE"

        echo "Copied: $FILE"

    else

        echo "Not generated: $FILE"

    fi

done

###############################################################################
# FIND ROM ZIP
###############################################################################

ROM_ZIP=""

for ZIP in "$PRODUCT_OUT"/lineage-22.1-*.zip; do

    if [ -f "$ZIP" ]; then
        ROM_ZIP="$ZIP"
        break
    fi

done

###############################################################################
# FINAL OUTPUT
###############################################################################

section "BUILD COMPLETE"

if [ -n "$ROM_ZIP" ]; then

    echo
    echo "ROM ZIP:"
    ls -lh "$ROM_ZIP"

else

    echo
    echo "WARNING: Lineage ROM ZIP was not found."

fi

echo
echo "IMAGE OUTPUT:"
ls -lh imgs_output/ 2>/dev/null || true

echo
echo "PRODUCT OUTPUT:"
echo "$PRODUCT_OUT"

###############################################################################
# SHA256
###############################################################################

section "GENERATING SHA256 HASHES"

if [ -n "$ROM_ZIP" ]; then
    sha256sum "$ROM_ZIP"
fi

for FILE in imgs_output/*.img; do
    if [ -f "$FILE" ]; then
        sha256sum "$FILE"
    fi
done

###############################################################################
# DONE
###############################################################################

echo
echo "============================================================"
echo " LINEAGEOS 22.1 + MINDTHEGAPPS BUILD FINISHED"
echo "============================================================"
echo
