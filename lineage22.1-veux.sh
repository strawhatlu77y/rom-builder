#!/bin/bash
set -e

echo "=============================================="
echo " LineageOS 22.1 VEUX / PEUX Crave Build"
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

    <project
        name="Amrito-Projects/device_xiaomi_veux"
        path="device/xiaomi/veux"
        revision="15"
        depth="1" />

    <project
        name="Amrito-Projects/vendor_xiaomi_veux-new"
        path="vendor/xiaomi/veux"
        revision="15"
        depth="1" />

    <project
        name="dereference23/kernel_xiaomi_sm6375"
        path="kernel/xiaomi/veux"
        revision="main"
        depth="1" />

    <project
        name="LineageOS/android_hardware_xiaomi"
        path="hardware/xiaomi"
        revision="lineage-22.1"
        depth="1" />

    <project
        name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi"
        path="hardware/qcom-caf/sm8350/audio/configs/holi"
        revision="14"
        depth="1" />

    <project
        name="Positron-B/vendor_xiaomi_miuicamera-veux"
        path="vendor/xiaomi/miuicamera-veux"
        revision="main"
        depth="1" />

    <project
        name="Positron-B/vendor_xiaomi_miuicamera"
        path="vendor/xiaomi/miuicamera"
        revision="main"
        depth="1" />

    <project
        name="userariii/vendor_sony_dolby"
        path="vendor/sony/dolby"
        revision="v1.0_sonyDAXUI"
        depth="1" />

    <project
        name="TogoFire/packages_apps_ViPER4AndroidFX"
        path="packages/apps/ViPER4AndroidFX"
        revision="v4a"
        depth="1" />

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
    hardware/qcom-caf/bootctrl
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
# 7. Remove obsolete vendor setup
# ============================================================

rm -f device/xiaomi/veux/vendorsetup.sh

# ============================================================
# 8. Remove obsolete QTI BootControl package references
# ============================================================

sed -i \
    '/android.hardware.boot-service.qti/d' \
    device/xiaomi/veux/device.mk

# ============================================================
# 9. Add QTI BootControl packages
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
# 10. Add QTI BootControl binaries if missing
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
# 11. Fix QTI GPT Utils UFS compatibility
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

echo "QTI GPT Utils configuration:"
grep -n -A5 -B2 \
    'USE_BSG_FRAMEWORK' \
    "$GPT_BP"

# ============================================================
# 12. Verify the UFS compatibility fix
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
# 13. BoardConfig compatibility
# ============================================================

if ! grep -q '^BOARD_OPENSOURCE_DIR *:=' \
    device/xiaomi/veux/BoardConfig.mk
then
    sed -i '1a\
\
BOARD_OPENSOURCE_DIR :=
' device/xiaomi/veux/BoardConfig.mk
fi

# ============================================================
# 14. Audio debug information
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
# 15. Build environment
# ============================================================

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

# ============================================================
# 16. Final source verification
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

echo "=============================================="
echo " Starting build environment"
echo "=============================================="

source build/envsetup.sh

breakfast veux

# ============================================================
# 17. IMPORTANT: Test GPT Utils before full ROM build
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
# 18. Full LineageOS build
# ============================================================

echo "=============================================="
echo " STARTING FULL LINEAGEOS BUILD"
echo "=============================================="

mka bacon

# ============================================================
# 19. Collect output
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

echo "=============================================="
echo " BUILD FINISHED"
echo "=============================================="
