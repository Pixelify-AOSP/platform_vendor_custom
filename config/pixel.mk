WITH_GMS := true

# Pixel Clocks
$(call inherit-product, vendor/pixel/clocks/products/clocks.mk)

# Pixel additions
$(call inherit-product, vendor/google/overlays/ThemeIcons/config.mk)
$(call inherit-product, vendor/pixel-style/config/common.mk)

# Don't dexpreopt GMS prebuilts.
DONT_DEXPREOPT_PREBUILTS := true

# Full GMS
$(call inherit-product, vendor/gms/gms_full.mk)


