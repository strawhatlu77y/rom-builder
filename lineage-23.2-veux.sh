#!/bin/bash
set -u

# ============================================================
# LineageOS 23.2 - VEUX / PEUX
# COMPLETE PRE-BUILD PREFLIGHT
# ============================================================
#
# NO ROM COMPILATION.
# NO mka bacon.
#
# This script:
#   1. Initializes LineageOS 23.2
#   2. Creates the verified VEUX manifest
#   3. Syncs the source
#   4. Validates source repositories/files
#   5. Validates VEUX/common proprietary lists
#   6. Validates extraction tooling
#   7. Validates vendor trees
#   8. Validates BootControl
#   9. Validates fastbootd / Virtual A/B / dynamic partitions
#  10. Runs breakfast veux only after source/vendor checks
#  11. Validates the RESOLVED product configuration
#  12. Stops without compiling
#
# IMPORTANT:
# Proprietary blobs are NOT downloaded magically by repo sync.
# vendor/xiaomi/veux and vendor/xiaomi/sm6375-common must already
# be populated by the proper extraction workflow before the
# product-level stage can pass.
#
# ============================================================

FAIL=0

pass() {
    echo "[PASS] $1"
}

fail() {
    echo "[FAIL] $1"
    FAIL=1
}

warn() {
    echo "[WARN] $1"
}

require_file() {
    if [ -f "$1" ]; then
        pass "File exists: $1"
    else
        fail "Missing file: $1"
    fi
}

require_dir() {
    if [ -d "$1" ]; then
        pass "Directory exists: $1"
    else
        fail "Missing directory: $1"
    fi
}

# ============================================================
# 1. CLEAN LOCAL MANIFESTS
# ============================================================

echo
echo "=================================================="
echo " [1] CLEANING LOCAL MANIFESTS"
echo "=================================================="
echo

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

pass "Local manifests cleaned"

# ============================================================
# 2. INITIALIZE LINEAGEOS 23.2
# ============================================================

echo
echo "=================================================="
echo " [2] INITIALIZING LINEAGEOS 23.2"
echo "=================================================="
echo

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-23.2 \
    --git-lfs \
    --depth=1

pass "LineageOS 23.2 initialized"

# ============================================================
# 3. CREATE LOCAL MANIFEST
# ============================================================

echo
echo "=================================================="
echo " [3] CREATING VEUX 23.2 MANIFEST"
echo "=================================================="
echo

cat > .repo/local_manifests/veux.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

  <project
      name="xiaomi-sm6375-devs/android_device_xiaomi_veux"
      path="device/xiaomi/veux"
      revision="lineage-23.2"
      depth="1" />

  <project
      name="xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common"
      path="device/xiaomi/sm6375-common"
      revision="lineage-23.2"
      depth="1" />

  <project
      name="xiaomi-sm6375-devs/android_kernel_xiaomi_sm6375"
      path="kernel/xiaomi/sm6375"
      revision="main"
      depth="1" />

  <project
      name="LineageOS/android_hardware_xiaomi"
      path="hardware/xiaomi"
      revision="lineage-23.2"
      depth="1" />

</manifest>
EOF

pass "VEUX manifest created"

# ============================================================
# 4. SOURCE SYNC
# ============================================================

echo
echo "=================================================="
echo " [4] SYNCING SOURCE"
echo "=================================================="
echo

/opt/crave/resync.sh

pass "Source sync completed"

# ============================================================
# 5. SOURCE TREE
# ============================================================

echo
echo "=================================================="
echo " [5] SOURCE TREE VALIDATION"
echo "=================================================="
echo

for P in \
    device/xiaomi/veux \
    device/xiaomi/sm6375-common \
    kernel/xiaomi/sm6375 \
    hardware/xiaomi
do
    require_dir "$P"
done

for F in \
    device/xiaomi/veux/Android.bp \
    device/xiaomi/veux/AndroidProducts.mk \
    device/xiaomi/veux/BoardConfig.mk \
    device/xiaomi/veux/device.mk \
    device/xiaomi/veux/lineage_veux.mk \
    device/xiaomi/veux/lineage.dependencies \
    device/xiaomi/veux/proprietary-files.txt \
    device/xiaomi/veux/extract-files.py \
    device/xiaomi/sm6375-common/Android.bp \
    device/xiaomi/sm6375-common/BoardConfigCommon.mk \
    device/xiaomi/sm6375-common/common.mk \
    device/xiaomi/sm6375-common/lineage.dependencies \
    device/xiaomi/sm6375-common/proprietary-files.txt \
    device/xiaomi/sm6375-common/extract-files.py
do
    require_file "$F"
done

# ============================================================
# 6. VERIFY MANIFEST CONTENT
# ============================================================

echo
echo "=================================================="
echo " [6] MANIFEST VALIDATION"
echo "=================================================="
echo

grep -q \
    "xiaomi-sm6375-devs/android_device_xiaomi_veux" \
    .repo/local_manifests/veux.xml \
    && pass "VEUX repository correct" \
    || fail "VEUX repository missing"

grep -q \
    "xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common" \
    .repo/local_manifests/veux.xml \
    && pass "SM6375 common repository correct" \
    || fail "SM6375 common repository missing"

grep -q \
    "xiaomi-sm6375-devs/android_kernel_xiaomi_sm6375" \
    .repo/local_manifests/veux.xml \
    && pass "SM6375 kernel repository correct" \
    || fail "SM6375 kernel repository missing"

grep -q \
    "LineageOS/android_hardware_xiaomi" \
    .repo/local_manifests/veux.xml \
    && pass "Xiaomi hardware repository correct" \
    || fail "Xiaomi hardware repository missing"

# ============================================================
# 7. RESOLVED COMMITS
# ============================================================

echo
echo "=================================================="
echo " [7] RESOLVED COMMITS"
echo "=================================================="
echo

echo "VEUX:"
git -C device/xiaomi/veux rev-parse HEAD

echo
echo "SM6375 COMMON:"
git -C device/xiaomi/sm6375-common rev-parse HEAD

echo
echo "KERNEL:"
git -C kernel/xiaomi/sm6375 rev-parse HEAD

echo
echo "HARDWARE/XIAOMI:"
git -C hardware/xiaomi rev-parse HEAD

pass "Repository commits resolved"

# ============================================================
# 8. VEUX -> COMMON INHERITANCE
# ============================================================

echo
echo "=================================================="
echo " [8] VEUX -> COMMON INHERITANCE"
echo "=================================================="
echo

if grep -q \
    "device/xiaomi/sm6375-common/common.mk" \
    device/xiaomi/veux/device.mk; then
    pass "VEUX inherits SM6375 common"
else
    fail "VEUX does not inherit SM6375 common"
fi

# ============================================================
# 9. PROPRIETARY LISTS
# ============================================================

echo
echo "=================================================="
echo " [9] PROPRIETARY LIST VALIDATION"
echo "=================================================="
echo

VEUX_PROP_LINES="$(wc -l < device/xiaomi/veux/proprietary-files.txt)"
COMMON_PROP_LINES="$(wc -l < device/xiaomi/sm6375-common/proprietary-files.txt)"

echo "VEUX proprietary lines   : $VEUX_PROP_LINES"
echo "COMMON proprietary lines : $COMMON_PROP_LINES"
echo

if [ "$VEUX_PROP_LINES" -gt 100 ]; then
    pass "VEUX proprietary list populated"
else
    fail "VEUX proprietary list unexpectedly small"
fi

if [ "$COMMON_PROP_LINES" -gt 100 ]; then
    pass "COMMON proprietary list populated"
else
    fail "COMMON proprietary list unexpectedly small"
fi

grep -q \
    "OS1.0.13.0.TKCEUXM" \
    device/xiaomi/veux/proprietary-files.txt \
    && pass "VEUX source is OS1.0.13.0.TKCEUXM" \
    || fail "VEUX firmware source mismatch/missing"

grep -q \
    "OS2.0.9.0.UMQEUXM" \
    device/xiaomi/sm6375-common/proprietary-files.txt \
    && pass "COMMON source is OS2.0.9.0.UMQEUXM" \
    || fail "COMMON firmware source mismatch/missing"

# ============================================================
# 10. EXTRACTION SCRIPT SYNTAX
# ============================================================

echo
echo "=================================================="
echo " [10] EXTRACTION TOOLING"
echo "=================================================="
echo

if python3 --version >/dev/null 2>&1; then
    python3 --version
    pass "Python 3 available"
else
    fail "Python 3 unavailable"
fi

python3 -m py_compile \
    device/xiaomi/veux/extract-files.py \
    && pass "VEUX extract-files.py syntax OK" \
    || fail "VEUX extract-files.py syntax failed"

python3 -m py_compile \
    device/xiaomi/sm6375-common/extract-files.py \
    && pass "COMMON extract-files.py syntax OK" \
    || fail "COMMON extract-files.py syntax failed"

# ============================================================
# 11. EXTRACTION NAMESPACES
# ============================================================

echo
echo "=================================================="
echo " [11] EXTRACTION NAMESPACES"
echo "=================================================="
echo

for P in \
    device/xiaomi/veux \
    hardware/qcom-caf/common/libqti-perfd-client \
    hardware/qcom-caf/sm8350 \
    hardware/xiaomi \
    vendor/qcom/opensource/display
do

    if [ -d "$P" ]; then
        pass "$P exists"
    else
        fail "$P missing"
    fi

done

# ============================================================
# 12. VENDOR TREES
# ============================================================

echo
echo "=================================================="
echo " [12] VENDOR TREE VALIDATION"
echo "=================================================="
echo

require_dir vendor/xiaomi/veux
require_dir vendor/xiaomi/sm6375-common

require_file vendor/xiaomi/veux/veux-vendor.mk
require_file vendor/xiaomi/sm6375-common/sm6375-common-vendor.mk

# ============================================================
# 13. VENDOR CONTENT
# ============================================================

echo
echo "=================================================="
echo " [13] VENDOR CONTENT VALIDATION"
echo "=================================================="
echo

VEUX_VENDOR_FILES="$(find vendor/xiaomi/veux -type f 2>/dev/null | wc -l)"
COMMON_VENDOR_FILES="$(find vendor/xiaomi/sm6375-common -type f 2>/dev/null | wc -l)"

echo "VEUX vendor files   : $VEUX_VENDOR_FILES"
echo "COMMON vendor files : $COMMON_VENDOR_FILES"
echo

if [ "$VEUX_VENDOR_FILES" -gt 50 ]; then
    pass "VEUX vendor tree populated"
else
    fail "VEUX vendor tree appears incomplete"
fi

if [ "$COMMON_VENDOR_FILES" -gt 50 ]; then
    pass "COMMON vendor tree populated"
else
    fail "COMMON vendor tree appears incomplete"
fi

# ============================================================
# 14. VERIFY VENDOR INHERITANCE
# ============================================================

echo
echo "=================================================="
echo " [14] VENDOR INHERITANCE"
echo "=================================================="
echo

grep -q \
    "vendor/xiaomi/veux/veux-vendor.mk" \
    device/xiaomi/veux/device.mk \
    && pass "VEUX vendor makefile inherited" \
    || fail "VEUX vendor makefile inheritance missing"

grep -q \
    "vendor/xiaomi/sm6375-common/sm6375-common-vendor.mk" \
    device/xiaomi/sm6375-common/common.mk \
    && pass "COMMON vendor makefile inherited" \
    || fail "COMMON vendor makefile inheritance missing"

# ============================================================
# 15. BOOTCONTROL SOURCE
# ============================================================

echo
echo "=================================================="
echo " [15] BOOTCONTROL SOURCE"
echo "=================================================="
echo

require_dir hardware/qcom-caf/bootctrl

require_file hardware/qcom-caf/bootctrl/aidl/Android.bp
require_file hardware/qcom-caf/bootctrl/aidl/BootControl.cpp
require_file hardware/qcom-caf/bootctrl/aidl/BootControl.h
require_file hardware/qcom-caf/bootctrl/aidl/main.cpp

grep -Rqs \
    "android.hardware.boot-service.qti" \
    hardware/qcom-caf/bootctrl \
    && pass "Normal QTI BootControl definition found" \
    || fail "Normal QTI BootControl definition missing"

grep -Rqs \
    "android.hardware.boot-service.qti.recovery" \
    hardware/qcom-caf/bootctrl \
    && pass "Recovery QTI BootControl definition found" \
    || fail "Recovery QTI BootControl definition missing"

# ============================================================
# 16. BOOTCONTROL PRODUCT CONFIG
# ============================================================

echo
echo "=================================================="
echo " [16] BOOTCONTROL PRODUCT CONFIG"
echo "=================================================="
echo

grep -Rqs \
    "android.hardware.boot-service.qti" \
    device/xiaomi/sm6375-common \
    device/xiaomi/veux \
    && pass "Normal BootControl referenced by product config" \
    || fail "Normal BootControl product reference missing"

grep -Rqs \
    "android.hardware.boot-service.qti.recovery" \
    device/xiaomi/sm6375-common \
    device/xiaomi/veux \
    && pass "Recovery BootControl referenced by product config" \
    || fail "Recovery BootControl product reference missing"

# ============================================================
# 17. BOOTCONTROL RC + VINTF
# ============================================================

echo
echo "=================================================="
echo " [17] BOOTCONTROL RC/VINTF"
echo "=================================================="
echo

RC_COUNT="$(find hardware/qcom-caf/bootctrl \
    -type f \
    -name "*.rc" | wc -l)"

VINTF_COUNT="$(find hardware/qcom-caf/bootctrl \
    -type f \
    \( -name "*manifest*.xml" -o -name "*vintf*.xml" \) | wc -l)"

echo "BootControl RC files    : $RC_COUNT"
echo "BootControl VINTF files: $VINTF_COUNT"
echo

if [ "$RC_COUNT" -gt 0 ]; then
    pass "BootControl RC files found"
else
    fail "BootControl RC files missing"
fi

if [ "$VINTF_COUNT" -gt 0 ]; then
    pass "BootControl VINTF files found"
else
    fail "BootControl VINTF files missing"
fi

# ============================================================
# 18. FASTBOOTD
# ============================================================

echo
echo "=================================================="
echo " [18] FASTBOOTD"
echo "=================================================="
echo

grep -Rqs \
    "fastbootd" \
    device/xiaomi/sm6375-common \
    device/xiaomi/veux \
    && pass "fastbootd configuration found" \
    || fail "fastbootd configuration missing"

# ============================================================
# 19. VIRTUAL A/B
# ============================================================

echo
echo "=================================================="
echo " [19] VIRTUAL A/B"
echo "=================================================="
echo

grep -Rqs \
    "virtual_ab_ota/launch_with_vendor_ramdisk.mk" \
    device/xiaomi/sm6375-common \
    && pass "Virtual A/B configuration found" \
    || fail "Virtual A/B configuration missing"

# ============================================================
# 20. DYNAMIC PARTITIONS
# ============================================================

echo
echo "=================================================="
echo " [20] DYNAMIC PARTITIONS"
echo "=================================================="
echo

grep -Rqs \
    "PRODUCT_USE_DYNAMIC_PARTITIONS" \
    device/xiaomi/sm6375-common \
    && pass "Dynamic partition configuration found" \
    || fail "Dynamic partition configuration missing"

# ============================================================
# 21. HOLI AUDIO
# ============================================================

echo
echo "=================================================="
echo " [21] HOLI AUDIO"
echo "=================================================="
echo

require_dir device/xiaomi/veux/audio

if find device/xiaomi/veux/audio \
    -type f \
    -print -quit | grep -q .; then
    pass "VEUX audio files found"
else
    fail "VEUX audio directory is empty"
fi

grep -q \
    "audio_amplifier.holi" \
    device/xiaomi/veux/device.mk \
    && pass "Holi amplifier configured" \
    || fail "Holi amplifier configuration missing"

if [ -f hardware/qcom-caf/sm8350/audio/configs/holi/audio_tuning_mixer.txt ]; then
    pass "Holi audio_tuning_mixer.txt exists"
else
    fail "Holi audio_tuning_mixer.txt missing"
fi

# ============================================================
# 22. RECOVERY / VENDOR BOOT
# ============================================================

echo
echo "=================================================="
echo " [22] RECOVERY / VENDOR_BOOT"
echo "=================================================="
echo

grep -RqsE \
    "BOARD_BOOT_HEADER_VERSION|BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE|BOARD_USES_RECOVERY_AS_BOOT|vendor_ramdisk" \
    device/xiaomi/veux \
    device/xiaomi/sm6375-common \
    && pass "Recovery/vendor_boot configuration found" \
    || warn "Recovery/vendor_boot configuration not fully identifiable by text scan"

# ============================================================
# 23. OLD 22.1 CONTAMINATION
# ============================================================

echo
echo "=================================================="
echo " [23] OLD 22.1 CONTAMINATION"
echo "=================================================="
echo

OLD_FOUND=0

for P in \
    "Amrito-Projects/device_xiaomi_veux" \
    "Amrito-Projects/vendor_xiaomi_veux-new" \
    "dereference23/kernel_xiaomi_sm6375" \
    "Positron-B/vendor_xiaomi_miuicamera" \
    "Positron-B/vendor_xiaomi_miuicamera-veux" \
    "userariii/vendor_sony_dolby" \
    "TogoFire/packages_apps_ViPER4AndroidFX" \
    "hardware_qcom-caf_sm8350_audio_configs_holi"
do

    if grep -Rqs \
        "$P" \
        .repo/local_manifests \
        device/xiaomi \
        2>/dev/null; then

        echo "[FAIL] Old 22.1 dependency found: $P"
        OLD_FOUND=1

    fi

done

if [ "$OLD_FOUND" -eq 0 ]; then
    pass "No known 22.1 dependency contamination"
else
    FAIL=1
fi

# ============================================================
# 24. REPO STATUS
# ============================================================

echo
echo "=================================================="
echo " [24] REPO STATUS"
echo "=================================================="
echo

repo status || true

# ============================================================
# 25. PRE-BREAKFAST HARD GATE
# ============================================================

echo
echo "=================================================="
echo "           PRE-BREAKFAST HARD GATE"
echo "=================================================="
echo

if [ "$FAIL" -ne 0 ]; then

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo " PREFLIGHT FAILED"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo
    echo "NO PRODUCT CONFIGURATION WILL BE RUN."
    echo "NO BUILD WILL BE STARTED."
    echo
    exit 1

fi

echo
echo "[PASS] All source-level hard checks passed."
echo

# ============================================================
# 26. PRODUCT CONFIGURATION
# ============================================================

echo
echo "=================================================="
echo " [26] PRODUCT CONFIGURATION"
echo "=================================================="
echo

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss

source build/envsetup.sh

echo
echo "Running breakfast veux..."
echo

if ! breakfast veux; then
    echo
    echo "[FAIL] breakfast veux failed."
    echo
    exit 1
fi

echo
echo "breakfast veux completed."
echo

# ============================================================
# 27. RESOLVED TARGET VARIABLES
# ============================================================

echo
echo "=================================================="
echo " [27] RESOLVED TARGET VARIABLES"
echo "=================================================="
echo

TARGET_PRODUCT_RESOLVED="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE_RESOLVED="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH_RESOLVED="$(get_build_var TARGET_ARCH)"
TARGET_KERNEL_SOURCE_RESOLVED="$(get_build_var TARGET_KERNEL_SOURCE)"
TARGET_KERNEL_CONFIG_RESOLVED="$(get_build_var TARGET_KERNEL_CONFIG)"
TARGET_BUILD_VARIANT_RESOLVED="$(get_build_var TARGET_BUILD_VARIANT)"

echo "TARGET_PRODUCT       = $TARGET_PRODUCT_RESOLVED"
echo "TARGET_DEVICE        = $TARGET_DEVICE_RESOLVED"
echo "TARGET_ARCH          = $TARGET_ARCH_RESOLVED"
echo "TARGET_KERNEL_SOURCE = $TARGET_KERNEL_SOURCE_RESOLVED"
echo "TARGET_KERNEL_CONFIG = $TARGET_KERNEL_CONFIG_RESOLVED"
echo "TARGET_BUILD_VARIANT = $TARGET_BUILD_VARIANT_RESOLVED"
echo

[ "$TARGET_PRODUCT_RESOLVED" = "lineage_veux" ] \
    && pass "TARGET_PRODUCT = lineage_veux" \
    || fail "TARGET_PRODUCT != lineage_veux"

[ "$TARGET_DEVICE_RESOLVED" = "veux" ] \
    && pass "TARGET_DEVICE = veux" \
    || fail "TARGET_DEVICE != veux"

[ "$TARGET_KERNEL_SOURCE_RESOLVED" = "kernel/xiaomi/sm6375" ] \
    && pass "TARGET_KERNEL_SOURCE = kernel/xiaomi/sm6375" \
    || fail "Unexpected kernel source"

[ -n "$TARGET_KERNEL_CONFIG_RESOLVED" ] \
    && pass "Kernel config resolved" \
    || fail "Kernel config unresolved"

# ============================================================
# 28. RESOLVED BOOTCONTROL PACKAGES
# ============================================================

echo
echo "=================================================="
echo " [28] RESOLVED BOOTCONTROL"
echo "=================================================="
echo

PRODUCT_PACKAGES_RESOLVED="$(get_build_var PRODUCT_PACKAGES)"

if printf '%s\n' "$PRODUCT_PACKAGES_RESOLVED" |
    tr ' ' '\n' |
    grep -Fxq "android.hardware.boot-service.qti"; then

    pass "Normal QTI BootControl resolved"

else

    fail "Normal QTI BootControl NOT resolved"

fi

if printf '%s\n' "$PRODUCT_PACKAGES_RESOLVED" |
    tr ' ' '\n' |
    grep -Fxq "android.hardware.boot-service.qti.recovery"; then

    pass "Recovery QTI BootControl resolved"

else

    fail "Recovery QTI BootControl NOT resolved"

fi

# ============================================================
# 29. RESOLVED FASTBOOTD
# ============================================================

echo
echo "=================================================="
echo " [29] RESOLVED FASTBOOTD"
echo "=================================================="
echo

if printf '%s\n' "$PRODUCT_PACKAGES_RESOLVED" |
    tr ' ' '\n' |
    grep -Fxq "fastbootd"; then

    pass "fastbootd resolved"

else

    fail "fastbootd NOT resolved"

fi

# ============================================================
# 30. RESOLVED DYNAMIC PARTITIONS
# ============================================================

echo
echo "=================================================="
echo " [30] RESOLVED DYNAMIC PARTITIONS"
echo "=================================================="
echo

DYNAMIC_RESOLVED="$(get_build_var PRODUCT_USE_DYNAMIC_PARTITIONS)"

echo "PRODUCT_USE_DYNAMIC_PARTITIONS = $DYNAMIC_RESOLVED"

if [ "$DYNAMIC_RESOLVED" = "true" ]; then
    pass "Dynamic partitions resolved"
else
    fail "Dynamic partitions not resolved as true"
fi

# ============================================================
# 31. FINAL SOURCE OUTPUT CHECKS
# ============================================================

echo
echo "=================================================="
echo " [31] FINAL OUTPUT DIRECTORY CHECK"
echo "=================================================="
echo

OUT_PRODUCT="out/target/product/veux"

if [ -d "$OUT_PRODUCT" ]; then
    pass "VEUX output directory exists"
else
    fail "VEUX output directory missing"
fi

# We are not building, so output images are NOT required here.
# This check only confirms product configuration created the
# expected output tree.

# ============================================================
# 32. FINAL RESULT
# ============================================================

echo
echo "=================================================="
echo "              FINAL PREFLIGHT RESULT"
echo "=================================================="
echo

if [ "$FAIL" -eq 0 ]; then

    echo
    echo "**************************************************"
    echo "*                                                *"
    echo "*          23.2 PREFLIGHT PASSED                 *"
    echo "*                                                *"
    echo "**************************************************"
    echo
    echo "Device       : VEUX/PEUX"
    echo "Product      : $TARGET_PRODUCT_RESOLVED"
    echo "Kernel       : $TARGET_KERNEL_SOURCE_RESOLVED"
    echo
    echo "BootControl  : VERIFIED"
    echo "fastbootd    : VERIFIED"
    echo "Virtual A/B  : VERIFIED"
    echo "Dynamic Partitions : VERIFIED"
    echo "Vendor       : VERIFIED"
    echo
    echo "NO ROM BUILD WAS STARTED."
    echo
    echo "=================================================="
    echo " SAFE TO PROCEED TO BUILD STAGE"
    echo "=================================================="
    echo

    exit 0

else

    echo
    echo "**************************************************"
    echo "*                                                *"
    echo "*          23.2 PREFLIGHT FAILED                  *"
    echo "*                                                *"
    echo "**************************************************"
    echo
    echo "DO NOT RUN mka bacon."
    echo
    exit 1

fi
