export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FixWANotifs

FixWANotifs_FILES = Tweak.x
FixWANotifs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

