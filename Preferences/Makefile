# MuteLock Preferences Bundle
# Makefile for the Settings UI

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MuteLockPrefs

MuteLockPrefs_FILES = MuteLockPrefsRootListController.m
MuteLockPrefs_INSTALL_PATH = /Library/PreferenceBundles
MuteLockPrefs_FRAMEWORKS = UIKit AVFoundation AVFAudio CoreServices
MuteLockPrefs_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
MuteLockPrefs_LDFLAGS = -F$(THEOS)/sdks/iPhoneOS11.4.sdk/System/Library/PrivateFrameworks -framework Preferences

include $(THEOS_MAKE_PATH)/bundle.mk
