$(call inherit-product, vendor/custom/config/common_mobile_full.mk)

# Enable support of one-handed mode
PRODUCT_PRODUCT_PROPERTIES += \
    ro.support_one_handed_mode?=true

# Inherit tablet common ASCP stuff
$(call inherit-product, vendor/custom/config/tablet.mk)

$(call inherit-product, vendor/custom/config/telephony.mk)

PRODUCT_PACKAGE_OVERLAYS += vendor/custom/overlay/foldable_book
