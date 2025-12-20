//
//  MuteLockPrefsRootListController.m
//  MuteLock Settings UI
//  By Yousef (@yousef_dev921)
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <notify.h>
#import "../MuteLockCommon.h"


#pragma mark - Localization

#define MUTELOCK_BUNDLE_PATH @"/var/jb/Library/PreferenceBundles/MuteLockPrefs.bundle"

static NSBundle *MuteLockBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bundle = [NSBundle bundleWithPath:MUTELOCK_BUNDLE_PATH];
        if (!bundle) bundle = [NSBundle mainBundle];
    });
    return bundle;
}

#define LOCALIZE(key) NSLocalizedStringFromTableInBundle(key, @"Localizable", MuteLockBundle(), nil)

static NSMutableDictionary *MLMutablePreferences(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kMuteLockPrefsPath];
    if (![prefs isKindOfClass:[NSDictionary class]]) return [NSMutableDictionary dictionary];
    return [prefs mutableCopy];
}

#pragma mark - MuteLockLogListController

@interface MuteLockLogListController : PSListController
@end

@implementation MuteLockLogListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = LOCALIZE(@"SECTION_LOG");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:LOCALIZE(@"CLEAR_LOG") style:UIBarButtonItemStylePlain target:self action:@selector(clearLog)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        
        // Read logs
        NSArray *logs = [NSArray arrayWithContentsOfFile:kMuteLockLogPath];
        if (!logs) logs = @[];
        
        if (logs.count == 0) {
            PSSpecifier *emptySpec = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"LOG_EMPTY") target:nil set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
            [specs addObject:emptySpec];
        } else {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterMediumStyle;
            
            for (NSDictionary *entry in logs) {
                NSString *bundleID = entry[@"bundleID"] ?: @"Unknown";
                NSString *type = entry[@"type"];
                NSNumber *timestamp = entry[@"timestamp"];
                
                NSString *typeStr = [type isEqualToString:@"camera"] ? LOCALIZE(@"LOG_CAMERA") : LOCALIZE(@"LOG_MIC");
                NSString *title = [NSString stringWithFormat:@"%@: %@", typeStr, bundleID];
                
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
                
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title target:nil set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
                [spec setProperty:[formatter stringFromDate:date] forKey:@"value"];
                [spec setProperty:@NO forKey:@"enabled"];
                [specs addObject:spec];
            }
        }
        
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)clearLog {
    [@[] writeToFile:kMuteLockLogPath atomically:YES];
    [self reloadSpecifiers];
}

@end

#pragma mark - MuteLockPrefsRootListController

@interface MuteLockPrefsRootListController : PSListController
@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic, assign) BOOL isTemporarilyUnlocked;
@end

@implementation MuteLockPrefsRootListController

- (instancetype)init {
    self = [super init];
    if (self) [self loadSettings];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"MuteLock";
    
    __block int token;
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch(kMuteLockNotifyStateChanged, &token, dispatch_get_main_queue(), ^(int t) {
        [weakSelf loadSettings];
        [weakSelf reloadSpecifiers];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadSettings];
    [self reloadSpecifiers];
}

#pragma mark - Settings

- (void)loadSettings {
    self.settings = MLMutablePreferences();
    
    if (!self.settings[kMuteLockEnabled]) self.settings[kMuteLockEnabled] = @NO;
    if (!self.settings[kMuteLockCameraLocked]) self.settings[kMuteLockCameraLocked] = @YES;
    if (!self.settings[kMuteLockMicLocked]) self.settings[kMuteLockMicLocked] = @YES;

    
    self.isTemporarilyUnlocked = [self.settings[kMuteLockTempUnlockActive] boolValue];
    if (self.isTemporarilyUnlocked) {
        NSNumber *expiryNum = self.settings[kMuteLockTempUnlockExpiry];
        if ([expiryNum respondsToSelector:@selector(doubleValue)]) {
            NSTimeInterval expiry = [expiryNum doubleValue];
            if ([[NSDate date] timeIntervalSince1970] > expiry) {
                self.isTemporarilyUnlocked = NO;
                [self lockNow];
            }
        }
    }
}

- (void)saveSettings {
    [self.settings writeToFile:kMuteLockPrefsPath atomically:YES];
    notify_post(kMuteLockNotifyStateChanged);
    notify_post(kMuteLockNotifyPrefsChanged);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return key ? self.settings[key] : nil;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key) {
        self.settings[key] = value;
        [self saveSettings];
    }
}

#pragma mark - Specifiers

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        
        // Protection
        [specs addObject:[PSSpecifier groupSpecifierWithName:LOCALIZE(@"SECTION_PROTECTION")]];
        
        PSSpecifier *enabledSpec = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"ENABLE_MUTELOCK") target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enabledSpec setProperty:kMuteLockEnabled forKey:@"key"];
        [enabledSpec setProperty:@NO forKey:@"default"];
        [specs addObject:enabledSpec];
        
        PSSpecifier *cameraSpec = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"LOCK_CAMERA") target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [cameraSpec setProperty:kMuteLockCameraLocked forKey:@"key"];
        [cameraSpec setProperty:@YES forKey:@"default"];
        [specs addObject:cameraSpec];
        
        PSSpecifier *micSpec = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"LOCK_MICROPHONE") target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [micSpec setProperty:kMuteLockMicLocked forKey:@"key"];
        [micSpec setProperty:@YES forKey:@"default"];
        [specs addObject:micSpec];
        
        
        // Temporary Unlock
        PSSpecifier *unlockGroup = [PSSpecifier groupSpecifierWithName:LOCALIZE(@"SECTION_TEMP_UNLOCK")];
        [unlockGroup setProperty:LOCALIZE(@"UNLOCK_FOOTER") forKey:@"footerText"];
        [specs addObject:unlockGroup];
        
        PSSpecifier *unlockButton = [PSSpecifier preferenceSpecifierNamed:(self.isTemporarilyUnlocked ? LOCALIZE(@"TAP_TO_LOCK") : LOCALIZE(@"REQUEST_UNLOCK")) target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [unlockButton setProperty:@YES forKey:@"enabled"];
        unlockButton.buttonAction = @selector(toggleUnlock:);
        [specs addObject:unlockButton];
        
        [specs addObject:[PSSpecifier groupSpecifierWithName:LOCALIZE(@"SECTION_LOG")]];
        
        PSSpecifier *logLink = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"VIEW_LOG") 
                                                              target:self 
                                                                 set:nil 
                                                                 get:nil 
                                                              detail:[MuteLockLogListController class] 
                                                                cell:PSLinkCell 
                                                                edit:nil];
        [specs addObject:logLink];
        
        
        // Developer
        [specs addObject:[PSSpecifier groupSpecifierWithName:LOCALIZE(@"SECTION_DEVELOPER")]];
        
        PSSpecifier *twitterSpec = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"TWITTER") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        twitterSpec.buttonAction = @selector(openTwitter:);
        [specs addObject:twitterSpec];
        
        PSSpecifier *donateSpec = [PSSpecifier preferenceSpecifierNamed:LOCALIZE(@"DONATE") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        donateSpec.buttonAction = @selector(openDonation:);
        [specs addObject:donateSpec];
        
        // Version
        PSSpecifier *versionGroup = [PSSpecifier groupSpecifierWithName:nil];
        [versionGroup setProperty:[NSString stringWithFormat:@"MuteLock v%@", MUTELOCK_VERSION] forKey:@"footerText"];
        [specs addObject:versionGroup];
        
        _specifiers = specs;
    }
    return _specifiers;
}

#pragma mark - Actions

- (void)toggleUnlock:(PSSpecifier *)specifier {
    if (self.isTemporarilyUnlocked) {
        [self lockNow];
    } else {
        [self grantTemporaryUnlock];
    }
}

- (void)grantTemporaryUnlock {
    NSTimeInterval duration = kMuteLockDefaultUnlockDuration;
    NSTimeInterval expiryTime = [[NSDate date] timeIntervalSince1970] + duration;
    
    self.settings[kMuteLockTempUnlockActive] = @YES;
    self.settings[kMuteLockTempUnlockExpiry] = @(expiryTime);
    [self saveSettings];
    
    self.isTemporarilyUnlocked = YES;
    [self reloadSpecifiers];
    
    // Simple confirmation (5 minutes = 300 seconds)
    [self showAlertWithTitle:LOCALIZE(@"UNLOCKED") message:LOCALIZE(@"UNLOCK_MESSAGE")];
}

- (void)lockNow {
    self.settings[kMuteLockTempUnlockActive] = @NO;
    [self.settings removeObjectForKey:kMuteLockTempUnlockExpiry];
    [self saveSettings];
    
    self.isTemporarilyUnlocked = NO;
    [self reloadSpecifiers];
}

#pragma mark - Helpers

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LOCALIZE(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openTwitter:(PSSpecifier *)specifier {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://x.com/yousef_dev921"] options:@{} completionHandler:nil];
}

- (void)openDonation:(PSSpecifier *)specifier {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://buymeacoffee.com/yousefzx9900"] options:@{} completionHandler:nil];
}

@end
