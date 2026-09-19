#!/bin/bash
set -e

echo "======================================"
echo " LineageOS 22.1 VEUX Build"
echo " Xiaomi VEUX / PEUX"
echo "======================================"

# ============================================================
# 1. CLEAN LOCAL MANIFESTS
# ============================================================

echo "[1/12] Cleaning local manifests..."

rm -rf .repo/local_manifests/
mkdir -p .repo/local_manifests


# ============================================================
# 2. INITIALIZE LINEAGEOS 22.1
# ============================================================

echo "[2/12] Initializing LineageOS 22.1..."

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1


# ============================================================
# 3. VEUX LOCAL MANIFEST
#
# IMPORTANT:
# DO NOT ADD hardware/qcom-caf/bootctrl HERE.
# Crave already provides it.
# ============================================================

echo "[3/12] Creating VEUX local manifest..."

cat > .repo/local_manifests/veux.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

  <!-- Device Tree -->
  <project
      name="Amrito-Projects/device_xiaomi_veux"
      path="device/xiaomi/veux"
      revision="15"
      depth="1" />

  <!-- Vendor -->
  <project
      name="Amrito-Projects/vendor_xiaomi_veux-new"
      path="vendor/xiaomi/veux"
      revision="15"
      depth="1" />

  <!-- Kernel -->
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

  <!-- Holi / SM8350 Audio Configs -->
  <project
      name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi"
      path="hardware/qcom-caf/sm8350/audio/configs/holi"
      revision="14"
      depth="1" />

  <!-- MIUI Camera -->
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
# 4. CRAVE SYNC
# ============================================================

echo "[4/12] Synchronizing source..."

/opt/crave/resync.sh


# ============================================================
# 5. CHECK BOOTCTRL
#
# Crave should already provide this path.
# ============================================================

echo "[5/12] Checking QTI BootControl..."

if [ -d "hardware/qcom-caf/bootctrl" ]; then
    echo "QTI BootControl directory found."

    echo "BootControl contents:"
    ls -la hardware/qcom-caf/bootctrl | head -30
else
    echo "ERROR: hardware/qcom-caf/bootctrl is missing."
    echo "Crave did not provide the expected BootControl tree."
    exit 1
fi


# ============================================================
# 6. CHECK KERNEL
# ============================================================

echo "[6/12] Checking kernel..."

if [ ! -d "kernel/xiaomi/veux" ]; then
    echo "ERROR: kernel/xiaomi/veux was not found."
    exit 1
fi

echo "Resolved kernel revision:"
git -C kernel/xiaomi/veux rev-parse HEAD

if ! find kernel/xiaomi/veux \
    -type f \
    -name "veux_defconfig" \
    -print \
    -quit | grep -q .; then

    echo "ERROR: veux_defconfig was not found."
    echo "Kernel sync failed or the selected kernel repository does not contain veux_defconfig."
    exit 1
fi

echo "veux_defconfig found — kernel OK"


# ============================================================
# 7. CHECK DEVICE TREE
# ============================================================

echo "[7/12] Checking device tree..."

if [ ! -d "device/xiaomi/veux" ]; then
    echo "ERROR: device/xiaomi/veux was not found."
    exit 1
fi

echo "VEUX device tree found."


# ============================================================
# 8. CHECK VENDOR
# ============================================================

echo "[8/12] Checking vendor..."

if [ ! -d "vendor/xiaomi/veux" ]; then
    echo "ERROR: vendor/xiaomi/veux was not found."
    exit 1
fi

echo "VEUX vendor tree found."


# ============================================================
# 9. DEVICE TREE FIXES
# ============================================================

echo "[9/12] Applying device tree fixes..."

# Remove vendorsetup.sh if present
rm -f device/xiaomi/veux/vendorsetup.sh


# ------------------------------------------------------------
# Remove any existing BootControl package declarations
# ------------------------------------------------------------

sed -i '/android.hardware.boot-service.qti/d' \
    device/xiaomi/veux/device.mk


# ------------------------------------------------------------
# Add QTI BootControl packages
# ------------------------------------------------------------

cat >> device/xiaomi/veux/device.mk << 'EOF'

# ============================================================
# QTI BootControl
# ============================================================

PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery

$(call soong_config_set,QTI_GPT_UTILS,USE_BSG_FRAMEWORK,false)

EOF


# ------------------------------------------------------------
# Expose Crave-provided BootControl to Soong
# ------------------------------------------------------------

if grep -q "hardware/qcom-caf/bootctrl" \
    device/xiaomi/veux/device.mk; then

    echo "BootControl namespace already present in device.mk."
else

    cat >> device/xiaomi/veux/device.mk << 'EOF'

# Make QTI BootControl visible to Soong
PRODUCT_SOONG_NAMESPACES += \
    hardware/qcom-caf/bootctrl

EOF

fi


# ============================================================
# 10. CAF AUDIO FIX
# ============================================================

echo "[10/12] Applying CAF audio fix..."

sed -i '1a\
\
BOARD_OPENSOURCE_DIR :=' \
    device/xiaomi/veux/BoardConfig.mk


# ------------------------------------------------------------
# Audio debug warning
# ------------------------------------------------------------

if ! grep -q "AUDIO_DEBUG:" \
    hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk; then

    sed -i '/endif # BOARD_OPENSOURCE_DIR/a $(warning AUDIO_DEBUG: BOARD_OPENSOURCE_DIR=[$(BOARD_OPENSOURCE_DIR)] PRIMARY_HAL_PATH=[$(PRIMARY_HAL_PATH)])' \
        hardware/qcom-caf/sm8350/audio/hal/audio_extn/Android.mk
fi


# ============================================================
# 11. VERIFY AUDIO CONFIG
# ============================================================

echo "[11/12] Checking Holi audio configuration..."

if [ ! -f \
    hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt ]; then

    echo "ERROR: audio_tuning_mixer.txt is missing."
    exit 1
fi

echo "Holi audio configs OK."


# ============================================================
# 12. VERIFY BOOTCONTROL CONFIGURATION
# ============================================================

echo "======================================"
echo " BootControl configuration"
echo "======================================"

grep -nA8 \
    "android.hardware.boot-service.qti" \
    device/xiaomi/veux/device.mk || true

echo ""
echo "Checking Soong namespace..."

grep -nA3 -B2 \
    "hardware/qcom-caf/bootctrl" \
    device/xiaomi/veux/device.mk || true


# ============================================================
# BUILD ENVIRONMENT
# ============================================================

echo ""
echo "======================================"
echo " Starting LineageOS build"
echo "======================================"

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss

# Keep this enabled as in the previous build setup.
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true


# ============================================================
# ENVSETUP
# ============================================================

source build/envsetup.sh


# ============================================================
# BREAKFAST
# ============================================================

echo ""
echo "Running breakfast veux..."

breakfast veux


# ============================================================
# BUILD
# ============================================================

echo ""
echo "======================================"
echo " Running mka bacon"
echo "======================================"

mka bacon


# ============================================================
# COPY OUTPUT IMAGES
# ============================================================

echo ""
echo "======================================"
echo " Collecting build images"
echo "======================================"

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
# FINAL RESULT
# ============================================================

echo ""
echo "======================================"
echo " BUILD FINISHED"
echo "======================================"

echo ""
echo "Flashable ZIP:"
find out/target/product/veux \
    -maxdepth 1 \
    -type f \
    -name "lineage-*.zip" \
    -print || true

echo ""
echo "ZIP files:"
ls -lh out/target/product/veux/*.zip 2>/dev/null || true

echo ""
echo "Images:"
ls -lh imgs_output/ 2>/dev/null || true

echo ""
echo "======================================"
echo " DONE"
echo "======================================"
