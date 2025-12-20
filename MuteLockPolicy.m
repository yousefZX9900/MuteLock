//
//  MuteLockPolicy.m
//  MuteLock - State management (Optimized with caching & timer)
//  By Yousef (@yousef_dev921)
//

#import "MuteLockPolicy.h"
#import <notify.h>

@interface MuteLockPolicy ()
@property (nonatomic, strong) NSDictionary *preferences;
@property (nonatomic, assign) int notifyToken;
@property (nonatomic, strong) dispatch_source_t unlockTimer;
@end

static NSDictionary *_cachedPreferences = nil;
static dispatch_once_t _prefsLoadToken;

static NSDictionary *MLReadPreferences(void) {
    dispatch_once(&_prefsLoadToken, ^{
        _cachedPreferences = [NSDictionary dictionaryWithContentsOfFile:kMuteLockPrefsPath] ?: @{};
    });
    return _cachedPreferences ?: @{};
}

static void MLResetPreferencesCache(void) {
    _prefsLoadToken = 0;
    _cachedPreferences = nil;
}

@implementation MuteLockPolicy

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static MuteLockPolicy *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MuteLockPolicy alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reloadState];
        [self registerForNotifications];
    }
    return self;
}

#pragma mark - Notifications

- (void)registerForNotifications {
    __weak typeof(self) weakSelf = self;
    
    notify_register_dispatch(kMuteLockNotifyStateChanged, &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        MLResetPreferencesCache();
        [weakSelf reloadState];
    });
    
    static int prefsToken;
    notify_register_dispatch(kMuteLockNotifyPrefsChanged, &prefsToken, dispatch_get_main_queue(), ^(int token) {
        MLResetPreferencesCache();
        [weakSelf reloadState];
    });
}

#pragma mark - State Loading

- (void)reloadState {
    BOOL prefsFileExists = [[NSFileManager defaultManager] fileExistsAtPath:kMuteLockPrefsPath];
    MLResetPreferencesCache();
    NSMutableDictionary *prefs = [MLReadPreferences() mutableCopy] ?: [NSMutableDictionary dictionary];
    
    if (!prefs[kMuteLockEnabled]) prefs[kMuteLockEnabled] = prefsFileExists ? @NO : @YES;
    if (!prefs[kMuteLockCameraLocked]) prefs[kMuteLockCameraLocked] = @YES;
    if (!prefs[kMuteLockMicLocked]) prefs[kMuteLockMicLocked] = @YES;
    
    self.preferences = prefs;
    
    [self checkAndExpireUnlock];
}

#pragma mark - Temporary Unlock Timer

- (void)checkAndExpireUnlock {
    if (![self.preferences[kMuteLockTempUnlockActive] boolValue]) {
        [self cancelUnlockTimer];
        return;
    }
    
    NSNumber *expiryNum = self.preferences[kMuteLockTempUnlockExpiry];
    if (!expiryNum) {
        [self lockNow];
        return;
    }
    
    NSTimeInterval remaining = [expiryNum doubleValue] - [[NSDate date] timeIntervalSince1970];
    
    if (remaining <= 0) {
        [self lockNow];
    } else {
        [self scheduleUnlockExpiryTimer:remaining];
    }
}

- (void)scheduleUnlockExpiryTimer:(NSTimeInterval)delay {
    [self cancelUnlockTimer];
    
    self.unlockTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.unlockTimer, 
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER, 
                              NSEC_PER_SEC); 
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.unlockTimer, ^{
        [weakSelf lockNow];
    });
    
    dispatch_resume(self.unlockTimer);
}

- (void)cancelUnlockTimer {
    if (self.unlockTimer) {
        dispatch_source_cancel(self.unlockTimer);
        self.unlockTimer = nil;
    }
}

- (void)lockNow {
    [self cancelUnlockTimer];
    
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    prefs[kMuteLockTempUnlockActive] = @NO;
    [prefs removeObjectForKey:kMuteLockTempUnlockExpiry];
    [prefs writeToFile:kMuteLockPrefsPath atomically:YES];
    
    _preferences = prefs;
    MLResetPreferencesCache();
    notify_post(kMuteLockNotifyStateChanged);
}

#pragma mark - State Properties

- (MuteLockState)currentState {
    if (![self.preferences[kMuteLockEnabled] boolValue]) return MuteLockStateDisabled;
    if ([self isTemporarilyUnlocked]) return MuteLockStateTemporarilyUnlocked;
    return MuteLockStateLocked;
}

- (BOOL)isCameraLocked {
    return [self.preferences[kMuteLockCameraLocked] boolValue];
}

- (BOOL)isMicrophoneLocked {
    return [self.preferences[kMuteLockMicLocked] boolValue];
}

- (BOOL)isTemporarilyUnlocked {
    if (![self.preferences[kMuteLockTempUnlockActive] boolValue]) return NO;
    NSDate *expiry = self.unlockExpiryDate;
    return expiry && [expiry timeIntervalSinceNow] > 0;
}

- (NSDate *)unlockExpiryDate {
    NSNumber *expiryTimestamp = self.preferences[kMuteLockTempUnlockExpiry];
    return expiryTimestamp ? [NSDate dateWithTimeIntervalSince1970:[expiryTimestamp doubleValue]] : nil;
}

- (NSTimeInterval)remainingUnlockTime {
    NSDate *expiry = self.unlockExpiryDate;
    if (!expiry) return 0;
    NSTimeInterval remaining = [expiry timeIntervalSinceNow];
    return remaining > 0 ? remaining : 0;
}

#pragma mark - Block Decisions

- (BOOL)shouldBlockCamera {
    return [self shouldBlockCameraForBundleID:nil];
}

- (BOOL)shouldBlockMicrophone {
    return [self shouldBlockMicrophoneForBundleID:nil];
}

- (BOOL)shouldBlockCameraForBundleID:(NSString *)bundleID {
    if (self.currentState == MuteLockStateDisabled) return NO;
    if (!self.isCameraLocked) return NO;
    if (self.currentState == MuteLockStateTemporarilyUnlocked) return NO;
    return YES;
}

- (BOOL)shouldBlockMicrophoneForBundleID:(NSString *)bundleID {
    if (self.currentState == MuteLockStateDisabled) return NO;
    if (!self.isMicrophoneLocked) return NO;
    if (self.currentState == MuteLockStateTemporarilyUnlocked) return NO;
    return YES;
}

@end
