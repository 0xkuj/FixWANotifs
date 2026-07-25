export TARGET = iphone:clang:14.5:14.5
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FixWANotifsPrefs

FixWANotifsPrefs_FILES = FWARootListController.m
FixWANotifsPrefs_FRAMEWORKS = UIKit
FixWANotifsPrefs_PRIVATE_FRAMEWORKS = Preferences
FixWANotifsPrefs_INSTALL_PATH = /Library/PreferenceBundles
FixWANotifsPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
