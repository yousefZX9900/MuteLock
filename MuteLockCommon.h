//
//  MuteLockCommon.h
//  MuteLock - Shared definitions (Optimized)
//  By Yousef (@yousef_dev921)
//

#ifndef MUTELOCK_COMMON_H
#define MUTELOCK_COMMON_H

#import <Foundation/Foundation.h>
#import <notify.h>

// Version Info
#define MUTELOCK_VERSION @"1.0.0"
#define MUTELOCK_BUNDLE_ID @"com.mutelock.tweak"

// Preferences Path (Rootless only)
#define kMuteLockPrefsPath @"/var/jb/var/mobile/Library/Preferences/com.mutelock.settings.plist"
#define kMuteLockLogPath @"/var/jb/var/mobile/Library/Preferences/com.mutelock.log.plist"

// Preference Keys
#define kMuteLockEnabled @"enabled"
#define kMuteLockCameraLocked @"cameraLocked"
#define kMuteLockMicLocked @"micLocked"
#define kMuteLockTempUnlockActive @"tempUnlockActive"
#define kMuteLockTempUnlockExpiry @"tempUnlockExpiry"

// Darwin Notifications
#define kMuteLockNotifyStateChanged "com.mutelock.state.changed"
#define kMuteLockNotifyLocked "com.mutelock.locked"
#define kMuteLockNotifyUnlocked "com.mutelock.unlocked"
#define kMuteLockNotifyPrefsChanged "com.mutelock.prefs.changed"
#define kMuteLockNotifyLogUpdated "com.mutelock.log.updated"

typedef NS_ENUM(NSInteger, MuteLockState) {
    MuteLockStateDisabled = 0,
    MuteLockStateLocked = 1,
    MuteLockStateTemporarilyUnlocked = 2
};

typedef NS_OPTIONS(NSUInteger, MuteLockSensorType) {
    MuteLockSensorNone = 0,
    MuteLockSensorCamera = 1 << 0,
    MuteLockSensorMicrophone = 1 << 1,
    MuteLockSensorAll = MuteLockSensorCamera | MuteLockSensorMicrophone
};

static inline BOOL MuteLockIsCameraService(NSString *serviceName) {
    if (!serviceName) return NO;
    static NSArray *patterns = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        patterns = @[
            // A12 Bionic (iPhone XS/XR) - H11
            @"AppleH11CamIn",
            // A13 Bionic (iPhone 11) - H12
            @"AppleH12CamIn",
            // A14 Bionic (iPhone 12) - H13
            @"AppleH13CamIn",
            // A15 Bionic (iPhone 13/14) - H14
            @"AppleH14CamIn",
            // A16 Bionic (iPhone 14 Pro/15) - H15
            @"AppleH15CamIn",
            // Generic patterns
            @"CamIn",
            @"AppleCamera",
            @"IOMFB",        // Display/Camera pipeline
            @"AppleAVE",     // Video encoder (used with camera)
            @"AppleJPEG",    // JPEG encoder for photos
            @"ISPFirmware"   // ISP firmware loading
        ];
    });
    for (NSString *pattern in patterns) {
        if ([serviceName containsString:pattern]) return YES;
    }
    return NO;
}

static inline BOOL MuteLockIsAudioInputService(NSString *serviceName) {
    if (!serviceName) return NO;
    static NSArray *patterns = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        patterns = @[@"IOAudioEngineUserClient", @"IOAudioEngine", @"AppleHDA", @"AudioInput", @"MicrophoneDevice"];
    });
    for (NSString *pattern in patterns) {
        if ([serviceName containsString:pattern]) return YES;
    }
    return NO;
}

// Optimized Logging with debounce (reduces I/O significantly)
static NSMutableArray *_pendingLogs = nil;
static dispatch_source_t _logFlushTimer = nil;

static void MuteLockFlushLogs(void);

static inline void MuteLockLogBlockedAccess(NSString *bundleID, NSString *type) {
    static dispatch_queue_t logQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logQueue = dispatch_queue_create("com.mutelock.log", DISPATCH_QUEUE_SERIAL);
        _pendingLogs = [NSMutableArray array];
    });
    
    if (!bundleID) bundleID = @"Unknown";
    if (!type) type = @"unknown";
    
    dispatch_async(logQueue, ^{
        @autoreleasepool {
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            
            // Check for duplicate in pending (same bundleID+type within 1 second)
            for (NSDictionary *entry in _pendingLogs) {
                if ([entry[@"bundleID"] isEqualToString:bundleID] &&
                    [entry[@"type"] isEqualToString:type] &&
                    (now - [entry[@"timestamp"] doubleValue]) < 1.0) {
                    return;
                }
            }
            
            NSDictionary *entry = @{
                @"bundleID": bundleID,
                @"type": type,
                @"timestamp": @(now)
            };
            
            [_pendingLogs addObject:entry];
            
            if (_logFlushTimer) {
                dispatch_source_cancel(_logFlushTimer);
                _logFlushTimer = nil;
            }
            
            _logFlushTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, logQueue);
            dispatch_source_set_timer(_logFlushTimer, 
                                      dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                                      DISPATCH_TIME_FOREVER, 0);
            dispatch_source_set_event_handler(_logFlushTimer, ^{
                MuteLockFlushLogs();
            });
            dispatch_resume(_logFlushTimer);
        }
    });
}

static void MuteLockFlushLogs(void) {
    if (!_pendingLogs || _pendingLogs.count == 0) return;
    
    NSMutableArray *logs = [NSMutableArray arrayWithContentsOfFile:kMuteLockLogPath] ?: [NSMutableArray array];
    
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _pendingLogs.count)];
    [logs insertObjects:_pendingLogs atIndexes:indexes];
    
    if (logs.count > 100) {
        [logs removeObjectsInRange:NSMakeRange(100, logs.count - 100)];
    }
    
    [logs writeToFile:kMuteLockLogPath atomically:YES];
    [_pendingLogs removeAllObjects];
    
    notify_post(kMuteLockNotifyLogUpdated);
}

#define kMuteLockDefaultUnlockDuration 300

#define MLLogAlways(fmt, ...) NSLog(@"[MuteLock] " fmt, ##__VA_ARGS__)

#endif
