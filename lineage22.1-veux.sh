#!/bin/bash
set -e

# Clean any existing local manifests
rm -rf .repo/local_manifests/

# Initialize LineageOS 22.1 source
repo init -u https://github.com/LineageOS/android.git -b lineage-22.1 --git-lfs --depth=1

# Create local manifest for all VEUX dependencies
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/veux.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="Amrito-Projects/device_xiaomi_veux" path="device/xiaomi/veux" revision="15" depth="1" />
  <project name="Amrito-Projects/vendor_xiaomi_veux-new" path="vendor/xiaomi/veux" revision="15" depth="1" />
  <!-- Kernel repository uses main explicitly -->
  <project name="dereference23/kernel_xiaomi_sm6375" path="kernel/xiaomi/veux" revision="main" depth="1" />
  <project name="LineageOS/android_hardware_xiaomi" path="hardware/xiaomi" revision="lineage-22.2" depth="1" />
  <project name="Amrito-Projects/hardware_qcom-caf_sm8350_audio_configs_holi" path="hardware/qcom-caf/sm8350/audio/configs/holi" revision="14" depth="1" />
  <project name="Positron-B/vendor_xiaomi_miuicamera-veux" path="vendor/xiaomi/miuicamera-veux" revision="main" depth="1" />
  <project name="Positron-B/vendor_xiaomi_miuicamera" path="vendor/xiaomi/miuicamera" revision="main" depth="1" />
  <project name="userariii/vendor_sony_dolby" path="vendor/sony/dolby" revision="v1.0_sonyDAXUI" depth="1" />
  <project name="TogoFire/packages_apps_ViPER4AndroidFX" path="packages/apps/ViPER4AndroidFX" revision="v4a" depth="1" />
</manifest>
EOF

/opt/crave/resync.sh

# Preflight: verify kernel synced correctly
echo "Resolved kernel revision:"
git -C kernel/xiaomi/veux rev-parse HEAD
test -n "$(find kernel/xiaomi/veux -type f -name "veux_defconfig" -print -quit)" || {
  echo "ERROR: veux_defconfig was not found — kernel sync failed"
  exit 1
}
echo "veux_defconfig found — kernel OK"

rm -f device/xiaomi/veux/vendorsetup.sh

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

source build/envsetup.sh
lunch lineage_veux-userdebug
mka bacon

mkdir -p imgs_output
cp out/target/product/veux/boot.img imgs_output/ 2>/dev/null || true
cp out/target/product/veux/dtbo.img imgs_output/ 2>/dev/null || true
cp out/target/product/veux/recovery.img imgs_output/ 2>/dev/null || true
cp out/target/product/veux/vendor_boot.img imgs_output/ 2>/dev/null || true

echo "====================================="
echo "Build finished. Flashable ZIP:"
find out/target/product/veux -maxdepth 1 -type f -name "lineage-*.zip" 2>/dev/null || echo "No ZIP found"
ls -lh out/target/product/veux/*.zip 2>/dev/null
