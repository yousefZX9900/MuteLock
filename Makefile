# MuteLock - Camera & Microphone Kill Switch
# iOS 15.0+ | Dopamine Rootless
# By Yousef (@yousef_dev921)

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = coreaudiod
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

# Main Tweak
TWEAK_NAME = MuteLock
MuteLock_FILES = Tweak.x MuteLockPolicy.m
MuteLock_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
MuteLock_FRAMEWORKS = Foundation UIKit IOKit AudioToolbox AVFoundation
MuteLock_LIBRARIES = bsm

include $(THEOS_MAKE_PATH)/tweak.mk

# Preferences Bundle
SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
