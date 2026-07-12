# Define tablet-specific variables
TARGET_IS_TABLET := true
WITH_GMS_COMMS_SUITE := false

# Inherit mobile full common ASCP stuff
$(call inherit-product, vendor/custom/config/common_mobile_full.mk)

# Inherit tablet common ASCP stuff
$(call inherit-product, vendor/custom/config/tablet.mk)

$(call inherit-product, vendor/custom/config/wifionly.mk)
