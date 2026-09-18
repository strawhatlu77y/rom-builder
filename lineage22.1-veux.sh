#!/bin/bash
set -e

# ============================================================
# LineageOS 22.1 - Xiaomi veux/peux
# ============================================================

rm -rf .repo/local_manifests/

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1

mkdir -p .repo/local_manifests

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

  <!-- Qualcomm BootControl -->
  <project
      name="LineageOS/android_hardware_qcom_bootctrl"
      path="hardware/qcom-caf/bootctrl"
      revision="lineage-22.1-caf"
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
# Verify device/vendor
# ============================================================

test -d device/xiaomi/veux || {
    echo "ERROR: device/xiaomi/veux missing"
    exit 1
}

test -d vendor/xiaomi/veux || {
    echo "ERROR: vendor/xiaomi/veux missing"
    exit 1
}

# ============================================================
# Verify Qualcomm BootControl source
# ============================================================

echo "============================================"
echo "Checking Qualcomm BootControl..."
echo "============================================"

test -f hardware/qcom-caf/bootctrl/Android.bp || {
    echo "ERROR: hardware/qcom-caf/bootctrl/Android.bp missing"
    exit 1
}

test -f hardware/qcom-caf/bootctrl/aidl/Android.bp || {
    echo "ERROR: hardware/qcom-caf/bootctrl/aidl/Android.bp missing"
    exit 1
}

test -f hardware/qcom-caf/bootctrl/aidl/main.cpp || {
    echo "ERROR: BootControl main.cpp missing"
    exit 1
}

test -f hardware/qcom-caf/bootctrl/aidl/BootControl.cpp || {
    echo "ERROR: BootControl.cpp missing"
    exit 1
}

grep -R \
    'android.hardware.boot-service.qti' \
    hardware/qcom-caf/bootctrl/aidl/Android.bp \
    >/dev/null || {
        echo "ERROR: QTI BootControl service definition missing"
        exit 1
    }

echo "Qualcomm BootControl source found — OK"

# ============================================================
# Device cleanup
# ============================================================

rm -f device/xiaomi/veux/vendorsetup.sh

# Remove our injected BootControl declarations if re-running
sed -i '/android.hardware.boot-service.qti/d' \
    device/xiaomi/veux/device.mk

sed -i '/QTI_GPT_UTILS.*USE_BSG_FRAMEWORK/d' \
    device/xiaomi/veux/device.mk

cat >> device/xiaomi/veux/device.mk << 'EOF'

# Qualcomm Boot Control HAL
PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery

$(call soong_config_set,QTI_GPT_UTILS,USE_BSG_FRAMEWORK,false)
EOF

# ============================================================
# IMPORTANT:
# Expose Qualcomm BootControl to Soong
# ============================================================

cat >> device/xiaomi/veux/device.mk << 'EOF'

# Qualcomm BootControl Soong namespace
PRODUCT_SOONG_NAMESPACES += \
    hardware/qcom-caf/bootctrl
EOF

echo "============================================"
echo "BootControl configuration:"
echo "============================================"

grep -nA8 \
    "android.hardware.boot-service.qti" \
    device/xiaomi/veux/device.mk

echo "============================================"
echo "BootControl Soong namespace:"
echo "============================================"

grep -nA2 \
    "hardware/qcom-caf/bootctrl" \
    device/xiaomi/veux/device.mk

# ============================================================
# Audio fix
# ============================================================

sed -i '1a\
\
BOARD_OPENSOURCE_DIR :=' \
    device/xiaomi/veux/BoardConfig.mk

sed -i \
    '/endif # BOARD_OPENSOURCE_DIR/a $(warning AUDIO_DEBUG: BOARD_OPENSOURCE_DIR=[$(BOARD_OPENSOURCE_DIR)] PRIMARY_HAL_PATH=[$(PRIMARY_HAL_PATH)])' \
    hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk

test -f \
    hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt || {
        echo "ERROR: audio_tuning_mixer.txt missing"
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

# ============================================================
# Confirm namespace reached product configuration
# ============================================================

echo "============================================"
echo "Final PRODUCT_SOONG_NAMESPACES:"
echo "============================================"

get_build_var PRODUCT_SOONG_NAMESPACES | tr ' ' '\n' | \
    grep -E 'bootctrl|qcom-caf' || true

# ============================================================
# Build
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
