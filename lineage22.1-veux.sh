#!/bin/bash
set -e

# ============================================================
# LineageOS 22.1 - Xiaomi veux/peux
# ============================================================

# Clean existing local manifests
rm -rf .repo/local_manifests/

# Initialize LineageOS 22.1
repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1

# ============================================================
# Local manifest
# ============================================================

mkdir -p .repo/local_manifests

cat > .repo/local_manifests/veux.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

  <!-- Xiaomi VEUX device tree -->
  <project
      name="Amrito-Projects/device_xiaomi_veux"
      path="device/xiaomi/veux"
      revision="15"
      depth="1" />

  <!-- Xiaomi VEUX vendor -->
  <project
      name="Amrito-Projects/vendor_xiaomi_veux-new"
      path="vendor/xiaomi/veux"
      revision="15"
      depth="1" />

  <!-- Xiaomi VEUX kernel -->
  <project
      name="dereference23/kernel_xiaomi_sm6375"
      path="kernel/xiaomi/veux"
      revision="main"
      depth="1" />

  <!-- Xiaomi hardware -->
  <project
      name="LineageOS/android_hardware_xiaomi"
      path="hardware/xiaomi"
      revision="lineage-22.1"
      depth="1" />

  <!-- Qualcomm BootControl HAL -->
  <project
      name="LineageOS/android_hardware_qcom_bootctrl"
      path="hardware/qcom-caf/bootctrl"
      revision="lineage-22.1-caf"
      depth="1" />

  <!-- Holi audio configs -->
  <project
      name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi"
      path="hardware/qcom-caf/sm8350/audio/configs/holi"
      revision="14"
      depth="1" />

  <!-- MIUI camera -->
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

  <!-- Sony Dolby -->
  <project
      name="userariii/vendor_sony_dolby"
      path="vendor/sony/dolby"
      revision="v1.0_sonyDAXUI"
      depth="1" />

  <!-- ViPER4Android -->
  <project
      name="TogoFire/packages_apps_ViPER4AndroidFX"
      path="packages/apps/ViPER4AndroidFX"
      revision="v4a"
      depth="1" />

</manifest>
EOF

# ============================================================
# Sync
# ============================================================

/opt/crave/resync.sh

# ============================================================
# Verify kernel
# ============================================================

echo "============================================"
echo "Checking kernel..."
echo "============================================"

echo "Resolved kernel revision:"
git -C kernel/xiaomi/veux rev-parse HEAD

test -n "$(find kernel/xiaomi/veux -type f -name "veux_defconfig" -print -quit)" || {
    echo "ERROR: veux_defconfig was not found"
    exit 1
}

echo "veux_defconfig found — kernel OK"

# ============================================================
# Verify device/vendor trees
# ============================================================

test -d device/xiaomi/veux || {
    echo "ERROR: device/xiaomi/veux was not found"
    exit 1
}

test -d vendor/xiaomi/veux || {
    echo "ERROR: vendor/xiaomi/veux was not found"
    exit 1
}

# ============================================================
# Verify Qualcomm BootControl repository
# ============================================================

echo "============================================"
echo "Checking Qualcomm BootControl..."
echo "============================================"

test -f hardware/qcom-caf/bootctrl/aidl/Android.bp || {
    echo "ERROR: Qualcomm BootControl Android.bp is missing"
    exit 1
}

test -f hardware/qcom-caf/bootctrl/aidl/main.cpp || {
    echo "ERROR: Qualcomm BootControl main.cpp is missing"
    exit 1
}

test -f hardware/qcom-caf/bootctrl/aidl/BootControl.cpp || {
    echo "ERROR: Qualcomm BootControl.cpp is missing"
    exit 1
}

grep -R \
    'android.hardware.boot-service.qti' \
    hardware/qcom-caf/bootctrl/aidl/Android.bp \
    >/dev/null || {
        echo "ERROR: QTI boot service definitions were not found"
        exit 1
    }

echo "Qualcomm BootControl source found — OK"

# ============================================================
# Remove vendorsetup.sh if present
# ============================================================

rm -f device/xiaomi/veux/vendorsetup.sh

# ============================================================
# BootControl configuration
# ============================================================

# Remove any existing BootControl package declarations
# so we don't duplicate them.
sed -i \
    '/android.hardware.boot-service.qti/d' \
    device/xiaomi/veux/device.mk

# Remove our old QTI GPT setting if it exists
sed -i \
    '/QTI_GPT_UTILS/d' \
    device/xiaomi/veux/device.mk

cat >> device/xiaomi/veux/device.mk << 'EOF'

# Qualcomm Boot Control HAL
PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery

$(call soong_config_set,QTI_GPT_UTILS,USE_BSG_FRAMEWORK,false)
EOF

echo "BootControl packages configured:"
grep -nA4 \
    "android.hardware.boot-service.qti" \
    device/xiaomi/veux/device.mk

# ============================================================
# CAF audio fix
# ============================================================

sed -i '1a\
\
BOARD_OPENSOURCE_DIR :=' \
    device/xiaomi/veux/BoardConfig.mk

# ============================================================
# Audio debug
# ============================================================

sed -i \
    '/endif # BOARD_OPENSOURCE_DIR/a $(warning AUDIO_DEBUG: BOARD_OPENSOURCE_DIR=[$(BOARD_OPENSOURCE_DIR)] PRIMARY_HAL_PATH=[$(PRIMARY_HAL_PATH)])' \
    hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk

# ============================================================
# Verify Holi audio
# ============================================================

test -f \
    hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt || {
        echo "ERROR: audio_tuning_mixer.txt is missing"
        exit 1
    }

echo "Holi audio configs OK"

# ============================================================
# Build
# ============================================================

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

source build/envsetup.sh

breakfast veux

mka bacon

# ============================================================
# Collect images
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
# Result
# ============================================================

echo ""
echo "============================================"
echo "BUILD FINISHED"
echo "============================================"

echo "Flashable ZIP:"
find out/target/product/veux \
    -maxdepth 1 \
    -type f \
    -name "lineage-*.zip" \
    2>/dev/null || echo "No ZIP found"

echo ""
echo "ZIP files:"
ls -lh \
    out/target/product/veux/*.zip \
    2>/dev/null || true

echo ""
echo "Images:"
ls -lh \
    imgs_output/* \
    2>/dev/null || true
