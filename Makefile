export TARGET = iphone:clang:14.5:14.5
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FixWANotifs

FixWANotifs_FILES = Tweak.x
FixWANotifs_CFLAGS = -fobjc-arc
FixWANotifs_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += FixWANotifsPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
