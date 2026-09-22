#!/bin/bash
set -e

echo "=============================================="
echo " LineageOS 22.1 VEUX / PEUX + MindTheGapps"
echo "=============================================="

# ============================================================
# 1. Clean local manifest and initialize source
# ============================================================

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1

# ============================================================
# 2. VEUX local manifest
# ============================================================

cat > .repo/local_manifests/veux.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

    <!-- VEUX Device Tree -->
    <project
        name="Amrito-Projects/device_xiaomi_veux"
        path="device/xiaomi/veux"
        revision="15"
        depth="1" />

    <!-- VEUX Vendor -->
    <project
        name="Amrito-Projects/vendor_xiaomi_veux-new"
        path="vendor/xiaomi/veux"
        revision="15"
        depth="1" />

    <!-- VEUX Kernel -->
    <project
        name="dereference23/kernel_xiaomi_sm6375"
        path="kernel/xiaomi/veux"
        revision="main"
        depth="1" />

    <!-- Xiaomi Hardware -->
    <project
        name="LineageOS/android_hardware_xiaomi"
        path="hardware/xiaomi"
        revision="lineage-22.1"
        depth="1" />

    <!-- Holi Audio Configuration -->
    <project
        name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi"
        path="hardware/qcom-caf/sm8350/audio/configs/holi"
        revision="14"
        depth="1" />

    <!-- MindTheGapps Android 15 -->
    <remote
        name="mindthegapps"
        fetch="https://gitlab.com/MindTheGapps/" />

    <project
        name="vendor_gapps"
        path="vendor/gapps"
        remote="mindthegapps"
        revision="e14b22768c60978d0e1267dab5bcf62dfcc73d16" />

</manifest>
EOF

echo "Local manifest created."

# ============================================================
# 3. Crave resync
# ============================================================

echo "=============================================="
echo " Running Crave resync"
echo "=============================================="

/opt/crave/resync.sh

# ============================================================
# 4. Verify required repositories
# ============================================================

echo "=============================================="
echo " Verifying source tree"
echo "=============================================="

for DIR in \
    device/xiaomi/veux \
    vendor/xiaomi/veux \
    kernel/xiaomi/veux \
    hardware/xiaomi \
    hardware/qcom-caf/bootctrl \
    hardware/qcom-caf/sm8350/audio/configs/holi \
    vendor/gapps
do
    if [ ! -d "$DIR" ]; then
        echo "ERROR: Missing required directory: $DIR"
        exit 1
    fi
done

echo "Required repositories found."

# ============================================================
# 5. Verify kernel
# ============================================================

echo "=============================================="
echo " Checking kernel"
echo "=============================================="

echo "Kernel revision:"
git -C kernel/xiaomi/veux rev-parse HEAD

if ! find kernel/xiaomi/veux \
    -type f \
    -name "veux_defconfig" \
    -print \
    -quit | grep -q .
then
    echo "ERROR: veux_defconfig was not found."
    exit 1
fi

echo "veux_defconfig found."

# ============================================================
# 6. Verify audio configuration
# ============================================================

if [ ! -f \
    hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt
]; then
    echo "ERROR: audio_tuning_mixer.txt is missing."
    exit 1
fi

echo "Audio configuration found."

# ============================================================
# 7. Verify MindTheGapps
# ============================================================

echo "=============================================="
echo " Checking MindTheGapps"
echo "=============================================="

GAPPS_MK="vendor/gapps/arm64/arm64-vendor.mk"

if [ ! -f "$GAPPS_MK" ]; then
    echo "ERROR: $GAPPS_MK not found."
    exit 1
fi

echo "MindTheGapps makefile found."

EXPECTED_GAPPS_COMMIT="e14b22768c60978d0e1267dab5bcf62dfcc73d16"
ACTUAL_GAPPS_COMMIT="$(git -C vendor/gapps rev-parse HEAD)"

echo "Expected GApps commit:"
echo "$EXPECTED_GAPPS_COMMIT"

echo "Actual GApps commit:"
echo "$ACTUAL_GAPPS_COMMIT"

if [ "$ACTUAL_GAPPS_COMMIT" != "$EXPECTED_GAPPS_COMMIT" ]; then
    echo "ERROR: MindTheGapps commit mismatch."
    exit 1
fi

echo "MindTheGapps commit verified."

# ============================================================
# 8. Remove obsolete vendor setup
# ============================================================

rm -f device/xiaomi/veux/vendorsetup.sh

# ============================================================
# 9. Remove old QTI BootControl references
# ============================================================

sed -i \
    '/android.hardware.boot-service.qti/d' \
    device/xiaomi/veux/device.mk

# ============================================================
# 10. Add QTI BootControl packages + namespace
# ============================================================

cat >> device/xiaomi/veux/device.mk << 'EOF'

# ============================================================
# QTI BootControl
# ============================================================

PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery

PRODUCT_SOONG_NAMESPACES += \
    hardware/qcom-caf/bootctrl

EOF

# ============================================================
# 11. Add QTI BootControl binaries if missing
# ============================================================

BOOTCTRL_BP="hardware/qcom-caf/bootctrl/aidl/Android.bp"

if [ ! -f "$BOOTCTRL_BP" ]; then
    echo "ERROR: $BOOTCTRL_BP not found."
    exit 1
fi

if ! grep -q 'name: "android.hardware.boot-service.qti",' "$BOOTCTRL_BP"; then

cat >> "$BOOTCTRL_BP" << 'EOF'

cc_binary {
    name: "android.hardware.boot-service.qti",
    defaults: ["android.hardware.boot-service.qti_defaults"],
    static_libs: ["libgptutils.qti"],
}

cc_binary {
    name: "android.hardware.boot-service.qti.recovery",
    defaults: ["android.hardware.boot-service.qti.recovery_defaults"],
    static_libs: ["libgptutils.qti"],
}

EOF

fi

# ============================================================
# 12. Fix QTI GPT Utils UFS compatibility
# ============================================================

GPT_BP="hardware/qcom-caf/bootctrl/gpt-utils/Android.bp"

if [ ! -f "$GPT_BP" ]; then
    echo "ERROR: $GPT_BP not found."
    exit 1
fi

echo "Applying QTI GPT Utils BSG compatibility fix..."

sed -i \
    's/"false": \[\],/"false": ["-D_BSG_FRAMEWORK_KERNEL_HEADERS"],/' \
    "$GPT_BP"

# ============================================================
# 13. Verify GPT fix
# ============================================================

if grep -q \
    '"false": \["-D_BSG_FRAMEWORK_KERNEL_HEADERS"\]' \
    "$GPT_BP"
then
    echo "GPT Utils BSG compatibility fix: PRESENT"
else
    echo "ERROR: GPT Utils BSG compatibility fix was NOT applied."
    exit 1
fi

# ============================================================
# 14. BoardConfig compatibility
# ============================================================

if ! grep -q '^BOARD_OPENSOURCE_DIR *:=' \
    device/xiaomi/veux/BoardConfig.mk
then
    sed -i '1a\
\
BOARD_OPENSOURCE_DIR :=
' device/xiaomi/veux/BoardConfig.mk
fi

echo "BOARD_OPENSOURCE_DIR: PRESENT"

# ============================================================
# 15. Audio debug information
# Retained from original working script
# ============================================================

AUDIO_MK="hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk"

if [ -f "$AUDIO_MK" ]; then

    if ! grep -q 'AUDIO_DEBUG:' "$AUDIO_MK"; then

        sed -i '/endif # BOARD_OPENSOURCE_DIR/a\
$(warning AUDIO_DEBUG: BOARD_OPENSOURCE_DIR=[$(BOARD_OPENSOURCE_DIR)] PRIMARY_HAL_PATH=[$(PRIMARY_HAL_PATH)])
' "$AUDIO_MK"

    fi

fi

# ============================================================
# 16. Remove MIUI Camera
# ============================================================

echo "=============================================="
echo " Removing MIUI Camera"
echo "=============================================="

sed -i \
    '/vendor\/xiaomi\/miuicamera-veux\/MiuiCamera-veux.mk/d' \
    device/xiaomi/veux/device.mk

sed -i \
    '/vendor\/xiaomi\/miuicamera-veux\/SEPolicy-veux.mk/d' \
    device/xiaomi/veux/BoardConfig.mk

sed -i \
    '/^# MiuiCamera$/d' \
    device/xiaomi/veux/device.mk

# ============================================================
# 17. Remove Dolby
# ============================================================

echo "=============================================="
echo " Removing Dolby"
echo "=============================================="

sed -i \
    '/vendor\/sony\/dolby\/setup.mk/d' \
    device/xiaomi/veux/device.mk

sed -i \
    '/^# Dolby$/d' \
    device/xiaomi/veux/device.mk

if grep -q '^AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP' \
    device/xiaomi/veux/BoardConfig.mk
then

    sed -i \
        's/^AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP.*/AUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP := false/' \
        device/xiaomi/veux/BoardConfig.mk

else

    printf '\nAUDIO_FEATURE_ENABLED_DS2_DOLBY_DAP := false\n' \
        >> device/xiaomi/veux/BoardConfig.mk

fi

echo "Dolby DAP disabled."

# ============================================================
# 18. Remove ViPER4AndroidFX
# ============================================================

echo "=============================================="
echo " Removing ViPER4AndroidFX"
echo "=============================================="

sed -i \
    '/packages\/apps\/ViPER4AndroidFX\/config.mk/d' \
    device/xiaomi/veux/device.mk

sed -i \
    '/^# Viper4AndroidFX$/d' \
    device/xiaomi/veux/device.mk

# ============================================================
# 19. Remove RemovePackagesVeux
# ============================================================

echo "=============================================="
echo " Removing RemovePackagesVeux"
echo "=============================================="

sed -i \
    '/RemovePackagesVeux/d' \
    device/xiaomi/veux/device.mk

sed -i \
    '/^# Remove unwanted packages$/d' \
    device/xiaomi/veux/device.mk

rm -rf device/xiaomi/veux/RemovePackages

# ============================================================
# 20. Keep XiaomiParts
# ============================================================

echo "=============================================="
echo " Keeping XiaomiParts"
echo "=============================================="

if ! grep -q 'XiaomiParts' device/xiaomi/veux/device.mk; then

cat >> device/xiaomi/veux/device.mk << 'EOF'

# Device-specific settings
PRODUCT_PACKAGES += \
    XiaomiParts

EOF

fi

if ! grep -q 'XiaomiParts' device/xiaomi/veux/device.mk; then
    echo "ERROR: XiaomiParts could not be enabled."
    exit 1
fi

echo "XiaomiParts: PRESENT"

# ============================================================
# 21. GMS configuration
# ============================================================

LINEAGE_MK="device/xiaomi/veux/lineage_veux.mk"

if [ ! -f "$LINEAGE_MK" ]; then
    echo "ERROR: lineage_veux.mk not found."
    exit 1
fi

if grep -q '^WITH_GMS' "$LINEAGE_MK"; then

    sed -i \
        's/^WITH_GMS.*/WITH_GMS := true/' \
        "$LINEAGE_MK"

else

cat >> "$LINEAGE_MK" << 'EOF'

WITH_GMS := true
EOF

fi

# ============================================================
# 22. Integrate MindTheGapps
# ============================================================

if ! grep -q \
    'vendor/gapps/arm64/arm64-vendor.mk' \
    "$LINEAGE_MK"
then

cat >> "$LINEAGE_MK" << 'EOF'

# ============================================================
# MindTheGapps Android 15 ARM64
# ============================================================

$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)

EOF

fi

# ============================================================
# 23. Remove requested optional packages
#
# Removed:
#   Seedvault
#   ThemePicker
#   Updater
#   QuickAccessWallet
#
# XiaomiParts is intentionally NOT included here.
# ============================================================

echo "=============================================="
echo " Removing optional packages"
echo "=============================================="

if ! grep -q '# VEUX requested package removals' "$LINEAGE_MK"; then

cat >> "$LINEAGE_MK" << 'EOF'

# ============================================================
# VEUX requested package removals
# ============================================================

PRODUCT_PACKAGES := $(filter-out \
    Seedvault \
    ThemePicker \
    Updater \
    QuickAccessWallet, \
    $(PRODUCT_PACKAGES))

EOF

fi

# ============================================================
# 24. Verify requested removals
# ============================================================

echo "=============================================="
echo " Final removal verification"
echo "=============================================="

BAD_REFS="$(
    grep -RInE \
        'miuicamera|MiuiCamera|vendor/sony/dolby|ViPER4AndroidFX|RemovePackagesVeux' \
        device/xiaomi/veux \
        2>/dev/null || true
)"

if [ -n "$BAD_REFS" ]; then
    echo "ERROR: Forbidden references still exist:"
    echo "$BAD_REFS"
    exit 1
fi

echo "MIUI Camera references: CLEAN"
echo "Dolby references: CLEAN"
echo "ViPER4AndroidFX references: CLEAN"
echo "RemovePackagesVeux references: CLEAN"

# ============================================================
# 25. Verify unwanted repositories are absent
# ============================================================

for DIR in \
    vendor/xiaomi/miuicamera-veux \
    vendor/xiaomi/miuicamera \
    vendor/sony/dolby \
    packages/apps/ViPER4AndroidFX
do

    if [ -e "$DIR" ]; then
        echo "ERROR: unwanted repository still exists: $DIR"
        exit 1
    fi

done

echo "MIUI Camera repositories: ABSENT"
echo "Dolby repository: ABSENT"
echo "ViPER4AndroidFX repository: ABSENT"

# ============================================================
# 26. Verify optional package filters
# ============================================================

for PACKAGE in \
    Seedvault \
    ThemePicker \
    Updater \
    QuickAccessWallet
do

    if ! grep -q "$PACKAGE" "$LINEAGE_MK"; then
        echo "ERROR: $PACKAGE removal filter is missing."
        exit 1
    fi

done

echo "Seedvault: FILTERED"
echo "ThemePicker: FILTERED"
echo "Updater: FILTERED"
echo "QuickAccessWallet: FILTERED"

# ============================================================
# 27. Verify XiaomiParts
# ============================================================

if ! grep -q 'XiaomiParts' device/xiaomi/veux/device.mk; then
    echo "ERROR: XiaomiParts is missing."
    exit 1
fi

echo "XiaomiParts: KEPT"

# ============================================================
# 28. Verify audio configuration
# ============================================================

echo "=============================================="
echo " Final audio verification"
echo "=============================================="

if ! grep -q 'audio.primary.holi' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: audio.primary.holi missing."
    exit 1
fi

if ! grep -q 'audio.bluetooth.default' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: audio.bluetooth.default missing."
    exit 1
fi

if ! grep -q 'audio.r_submix.default' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: audio.r_submix.default missing."
    exit 1
fi

if ! grep -q 'audio.usb.default' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: audio.usb.default missing."
    exit 1
fi

if ! grep -q 'audio_tuning_mixer.txt' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: audio_tuning_mixer.txt reference missing."
    exit 1
fi

echo "Qualcomm/Holi audio configuration: PRESENT"

# ============================================================
# 29. Verify BootControl
# ============================================================

echo "=============================================="
echo " Final BootControl verification"
echo "=============================================="

if ! grep -q \
    'android.hardware.boot-service.qti' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: QTI BootControl service missing."
    exit 1
fi

if ! grep -q \
    'android.hardware.boot-service.qti.recovery' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: QTI recovery BootControl service missing."
    exit 1
fi

if ! grep -q \
    'hardware/qcom-caf/bootctrl' \
    device/xiaomi/veux/device.mk
then
    echo "ERROR: QTI BootControl Soong namespace missing."
    exit 1
fi

echo "QTI BootControl configuration: PRESENT"

# ============================================================
# 30. Verify BOARD_OPENSOURCE_DIR
# ============================================================

if ! grep -q '^BOARD_OPENSOURCE_DIR *:=' \
    device/xiaomi/veux/BoardConfig.mk
then
    echo "ERROR: BOARD_OPENSOURCE_DIR missing."
    exit 1
fi

echo "BOARD_OPENSOURCE_DIR: PRESENT"

# ============================================================
# 31. Verify GMS + MindTheGapps
# ============================================================

echo "=============================================="
echo " Final GMS verification"
echo "=============================================="

if ! grep -q '^WITH_GMS := true' "$LINEAGE_MK"; then
    echo "ERROR: WITH_GMS is not enabled."
    exit 1
fi

if ! grep -q \
    'vendor/gapps/arm64/arm64-vendor.mk' \
    "$LINEAGE_MK"
then
    echo "ERROR: MindTheGapps inheritance missing."
    exit 1
fi

echo "WITH_GMS: ENABLED"
echo "MindTheGapps: ENABLED"

# ============================================================
# 32. Check GMS partition reserved sizes
# ============================================================

echo "=============================================="
echo " Checking GMS partition reserved space"
echo "=============================================="

if grep -q \
    'BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 25165824' \
    device/xiaomi/veux/BoardConfig.mk
then
    echo "System reserved size: 24 MiB"
else
    echo "WARNING: System reserved size is not 24 MiB."
fi

if grep -q \
    'BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE := 25165824' \
    device/xiaomi/veux/BoardConfig.mk
then
    echo "System_ext reserved size: 24 MiB"
else
    echo "WARNING: System_ext reserved size is not 24 MiB."
fi

if grep -q \
    'BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 25165824' \
    device/xiaomi/veux/BoardConfig.mk
then
    echo "Product reserved size: 24 MiB"
else
    echo "WARNING: Product reserved size is not 24 MiB."
fi

# ============================================================
# 33. Build environment
# ============================================================

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

# ============================================================
# 34. Final source verification
# ============================================================

echo "=============================================="
echo " FINAL SOURCE CHECK"
echo "=============================================="

echo "Device:"
ls -ld device/xiaomi/veux

echo "Vendor:"
ls -ld vendor/xiaomi/veux

echo "Kernel:"
ls -ld kernel/xiaomi/veux

echo "BootControl:"
ls -ld hardware/qcom-caf/bootctrl

echo "GPT Utils:"
ls -ld hardware/qcom-caf/bootctrl/gpt-utils

echo "Holi Audio:"
ls -ld hardware/qcom-caf/sm8350/audio/configs/holi

echo "MindTheGapps:"
ls -ld vendor/gapps

# ============================================================
# 35. Start build environment
# ============================================================

echo "=============================================="
echo " Starting build environment"
echo "=============================================="

source build/envsetup.sh

breakfast veux

# ============================================================
# 36. IMPORTANT: Test GPT Utils before full ROM build
# ============================================================

echo "=============================================="
echo " TESTING QTI GPT UTILS"
echo "=============================================="

echo "Building libgptutils.qti..."
echo "This is a small pre-flight test."
echo "If this fails, the full ROM build will NOT start."

m libgptutils.qti -j$(nproc)

echo "=============================================="
echo " QTI GPT UTILS TEST PASSED"
echo "=============================================="

# ============================================================
# 37. Full LineageOS + MindTheGapps build
# ============================================================

echo "=============================================="
echo " STARTING FULL LINEAGEOS + GAPPS BUILD"
echo "=============================================="

mka bacon

# ============================================================
# 38. Collect output
# ============================================================

mkdir -p imgs_output

cp out/target/product/veux/boot.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/dtbo.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/recovery.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/vendor_boot.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/vbmeta.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/vbmeta_system.img \
    imgs_output/ 2>/dev/null || true

# ============================================================
# 39. Build output
# ============================================================

echo "=============================================="
echo " BUILD OUTPUT"
echo "=============================================="

find out/target/product/veux \
    -maxdepth 1 \
    -type f \
    -name "lineage-*.zip" \
    -print || true

echo "=============================================="
echo " ZIP FILES"
echo "=============================================="

ls -lh \
    out/target/product/veux/*.zip \
    2>/dev/null || true

echo "=============================================="
echo " IMAGE OUTPUT"
echo "=============================================="

ls -lh \
    imgs_output/ \
    2>/dev/null || true

# ============================================================
# 40. SHA256
# ============================================================

echo "=============================================="
echo " SHA256"
echo "=============================================="

for FILE in \
    out/target/product/veux/*.zip \
    imgs_output/*.img
do
    if [ -f "$FILE" ]; then
        sha256sum "$FILE"
    fi
done

# ============================================================
# DONE
# ============================================================

echo "=============================================="
echo " BUILD FINISHED"
echo "=============================================="
