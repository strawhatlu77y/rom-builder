#!/bin/bash
set -e

echo "======================================"
echo " LineageOS 22.1 VEUX Build"
echo " Xiaomi VEUX / PEUX"
echo "======================================"

rm -rf .repo/local_manifests/
mkdir -p .repo/local_manifests

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1

cat > .repo/local_manifests/veux.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="Amrito-Projects/device_xiaomi_veux" path="device/xiaomi/veux" revision="15" depth="1" />
  <project name="Amrito-Projects/vendor_xiaomi_veux-new" path="vendor/xiaomi/veux" revision="15" depth="1" />
  <project name="dereference23/kernel_xiaomi_sm6375" path="kernel/xiaomi/veux" revision="main" depth="1" />
  <project name="LineageOS/android_hardware_xiaomi" path="hardware/xiaomi" revision="lineage-22.1" depth="1" />
  <project name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi" path="hardware/qcom-caf/sm8350/audio/configs/holi" revision="14" depth="1" />
  <project name="Positron-B/vendor_xiaomi_miuicamera-veux" path="vendor/xiaomi/miuicamera-veux" revision="main" depth="1" />
  <project name="Positron-B/vendor_xiaomi_miuicamera" path="vendor/xiaomi/miuicamera" revision="main" depth="1" />
  <project name="userariii/vendor_sony_dolby" path="vendor/sony/dolby" revision="v1.0_sonyDAXUI" depth="1" />
  <project name="TogoFire/packages_apps_ViPER4AndroidFX" path="packages/apps/ViPER4AndroidFX" revision="v4a" depth="1" />
</manifest>
EOF

/opt/crave/resync.sh

# ============================================================
# Verify QTI BootControl
# ============================================================

if [ -d "hardware/qcom-caf/bootctrl" ]; then
    echo "QTI BootControl directory found."
    ls -la hardware/qcom-caf/bootctrl | head -30
else
    echo "ERROR: hardware/qcom-caf/bootctrl is missing."
    exit 1
fi

# ============================================================
# Verify kernel
# ============================================================

if [ ! -d "kernel/xiaomi/veux" ]; then
    echo "ERROR: kernel/xiaomi/veux was not found."
    exit 1
fi

echo "Resolved kernel revision:"
git -C kernel/xiaomi/veux rev-parse HEAD

if ! find kernel/xiaomi/veux -type f -name "veux_defconfig" -print -quit | grep -q .; then
    echo "ERROR: veux_defconfig was not found."
    exit 1
fi

echo "veux_defconfig found — kernel OK"

# ============================================================
# Verify device/vendor
# ============================================================

if [ ! -d "device/xiaomi/veux" ]; then
    echo "ERROR: device/xiaomi/veux was not found."
    exit 1
fi

if [ ! -d "vendor/xiaomi/veux" ]; then
    echo "ERROR: vendor/xiaomi/veux was not found."
    exit 1
fi

# ============================================================
# Device tree fixes
# ============================================================

rm -f device/xiaomi/veux/vendorsetup.sh

sed -i '/android.hardware.boot-service.qti/d' device/xiaomi/veux/device.mk

cat >> device/xiaomi/veux/device.mk << 'EOF'

# ============================================================
# QTI BootControl
# ============================================================

PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery

$(call soong_config_set,QTI_GPT_UTILS,USE_BSG_FRAMEWORK,false)

EOF

# ============================================================
# Make QTI BootControl visible to Soong
# ============================================================

if grep -q "hardware/qcom-caf/bootctrl" device/xiaomi/veux/device.mk; then
    echo "BootControl namespace already present in device.mk."
else
    cat >> device/xiaomi/veux/device.mk << 'EOF'

# Make QTI BootControl visible to Soong
PRODUCT_SOONG_NAMESPACES += \
    hardware/qcom-caf/bootctrl

EOF
fi

# ============================================================
# Add missing QTI BootControl binaries
#
# The synced AIDL Android.bp contains the defaults but does not
# define the final cc_binary modules.
# ============================================================

if grep -q 'name: "android.hardware.boot-service.qti",' \
    hardware/qcom-caf/bootctrl/aidl/Android.bp; then

    echo "QTI BootControl binaries already defined."

else

    echo "Adding missing QTI BootControl binaries..."

    cat >> hardware/qcom-caf/bootctrl/aidl/Android.bp << 'EOF'

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
# BoardConfig fix
# ============================================================

sed -i '1a\
\
BOARD_OPENSOURCE_DIR :=' device/xiaomi/veux/BoardConfig.mk

# ============================================================
# Audio debug information
# ============================================================

if ! grep -q "AUDIO_DEBUG:" \
    hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk; then

    sed -i '/endif # BOARD_OPENSOURCE_DIR/a $(warning AUDIO_DEBUG: BOARD_OPENSOURCE_DIR=[$(BOARD_OPENSOURCE_DIR)] PRIMARY_HAL_PATH=[$(PRIMARY_HAL_PATH)])' \
        hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk
fi

# ============================================================
# Verify Holi audio configuration
# ============================================================

if [ ! -f hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt ]; then
    echo "ERROR: audio_tuning_mixer.txt is missing."
    exit 1
fi

# ============================================================
# Diagnostics
# ============================================================

echo "======================================"
echo " BootControl configuration"
echo "======================================"

grep -nA8 \
    "android.hardware.boot-service.qti" \
    device/xiaomi/veux/device.mk || true

grep -nA3 -B2 \
    "hardware/qcom-caf/bootctrl" \
    device/xiaomi/veux/device.mk || true

echo "======================================"
echo " BootControl binaries"
echo "======================================"

grep -nA4 -B1 \
    'name: "android.hardware.boot-service.qti"' \
    hardware/qcom-caf/bootctrl/aidl/Android.bp || true

grep -nA4 -B1 \
    'name: "android.hardware.boot-service.qti.recovery"' \
    hardware/qcom-caf/bootctrl/aidl/Android.bp || true

# ============================================================
# Build environment
# ============================================================

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

source build/envsetup.sh

# ============================================================
# Configure device
# ============================================================

breakfast veux

# ============================================================
# Build LineageOS
# ============================================================

mka bacon

# ============================================================
# Collect output
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

# ============================================================
# Show ROM ZIP
# ============================================================

echo "======================================"
echo " Build output"
echo "======================================"

find out/target/product/veux \
    -maxdepth 1 \
    -type f \
    -name "lineage-*.zip" \
    -print || true

ls -lh out/target/product/veux/*.zip \
    2>/dev/null || true

ls -lh imgs_output/ \
    2>/dev/null || true

echo "======================================"
echo " Build script finished"
echo "======================================"
