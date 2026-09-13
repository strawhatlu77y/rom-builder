#!/bin/bash
set -e

echo "=============================================="
echo " LineageOS 22.1 - Xiaomi VEUX"
echo "=============================================="

# ==================================================
# 1. Clean local manifests
# ==================================================
echo "[1/9] Cleaning local manifests..."

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

# ==================================================
# 2. Initialize LineageOS 22.1
# ==================================================
echo "[2/9] Initializing LineageOS 22.1..."

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-22.1 \
    --git-lfs \
    --depth=1

# ==================================================
# 3. VEUX local manifest
# ==================================================
echo "[3/9] Creating VEUX local manifest..."

cat > .repo/local_manifests/veux.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

  <!-- VEUX device tree -->
  <project
      name="Amrito-Projects/device_xiaomi_veux"
      path="device/xiaomi/veux"
      revision="15"
      depth="1" />

  <!-- VEUX vendor -->
  <project
      name="Amrito-Projects/vendor_xiaomi_veux-new"
      path="vendor/xiaomi/veux"
      revision="15"
      depth="1" />

  <!-- VEUX kernel -->
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

  <!-- Complete Qualcomm CAF audio HAL -->
  <project
      name="LineageOS/android_hardware_qcom_audio"
      path="hardware/qcom-caf/sm8350/audio"
      revision="lineage-22.1-caf-sm8350"
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

# ==================================================
# 4. Sync source
# ==================================================
echo "[4/9] Syncing source..."

/opt/crave/resync.sh

# ==================================================
# 5. Kernel preflight
# ==================================================
echo "[5/9] Checking kernel..."

KERNEL_DIR="kernel/xiaomi/veux"

echo "Kernel revision:"
git -C "$KERNEL_DIR" rev-parse HEAD

if ! find "$KERNEL_DIR" -type f -name "veux_defconfig" -print -quit | grep -q .; then
    echo "ERROR: veux_defconfig not found. Kernel sync failed."
    exit 1
fi

echo "OK: veux_defconfig found."

# ==================================================
# 6. Qualcomm audio preflight
# ==================================================
echo "[6/9] Checking Qualcomm audio..."

AUDIO_DIR="hardware/qcom-caf/sm8350/audio"

test -f "$AUDIO_DIR/hal/audio_hw.h" || {
    echo "ERROR: audio_hw.h missing. Stopping build."
    exit 1
}

test -f "$AUDIO_DIR/hal/audio_extn/compress_capture.c" || {
    echo "ERROR: compress_capture.c missing."
    exit 1
}

test -f "$AUDIO_DIR/hal/audio_extn/edid.c" || {
    echo "ERROR: edid.c missing."
    exit 1
}

test -f "$AUDIO_DIR/hal/Android.mk" || {
    echo "ERROR: audio/hal/Android.mk missing."
    exit 1
}

test -f "$AUDIO_DIR/hal/audio_extn/Android.mk" || {
    echo "ERROR: audio_extn/Android.mk missing."
    exit 1
}

echo "Audio revision: $(git -C "$AUDIO_DIR" rev-parse HEAD)"
echo "===== AUDIO PREFLIGHT PASSED ====="

# ==================================================
# 7. VEUX compatibility fixes & environment flags
# ==================================================
echo "[7/9] Applying VEUX compatibility fixes..."

rm -f device/xiaomi/veux/vendorsetup.sh

# Remove obsolete bootctrl references
sed -i '/android.hardware.boot/d' device/xiaomi/veux/device.mk

# Environment configuration
export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

# ==================================================
# 8. Configure build
# ==================================================
echo "[8/9] Configuring build..."

source build/envsetup.sh

breakfast veux

echo ""
echo "=============================================="
echo " PRE-BUILD CHECKS PASSED"
echo " Starting mka bacon..."
echo "=============================================="
echo ""

# ==================================================
# 9. Build
# ==================================================
mka bacon

# ==================================================
# Collect output
# ==================================================
echo ""
echo "=============================================="
echo " BUILD FINISHED"
echo "=============================================="

mkdir -p imgs_output

cp out/target/product/veux/boot.img imgs_output/ 2>/dev/null || true
cp out/target/product/veux/dtbo.img imgs_output/ 2>/dev/null || true
cp out/target/product/veux/recovery.img imgs_output/ 2>/dev/null || true
cp out/target/product/veux/vendor_boot.img imgs_output/ 2>/dev/null || true

echo ""
echo "Flashable ZIP:"
find out/target/product/veux -maxdepth 1 -type f -name "lineage-*.zip" -print 2>/dev/null || echo "No ZIP found"

echo ""
echo "ZIP details:"
ls -lh out/target/product/veux/*.zip 2>/dev/null || true

echo "=============================================="
echo " SCRIPT COMPLETE"
echo "=============================================="
