//
//  MuteLockPolicy.h
//  MuteLock
//
//  Created by Yousef on 8/27/2025.
//

#import <Foundation/Foundation.h>
#import "MuteLockCommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface MuteLockPolicy : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) MuteLockState currentState;
@property (nonatomic, readonly) BOOL isCameraLocked;
@property (nonatomic, readonly) BOOL isMicrophoneLocked;
@property (nonatomic, readonly) BOOL isTemporarilyUnlocked;
@property (nonatomic, readonly, nullable) NSDate *unlockExpiryDate;
- (BOOL)shouldBlockCameraForBundleID:(nullable NSString *)bundleID;
- (BOOL)shouldBlockMicrophoneForBundleID:(nullable NSString *)bundleID;

- (void)reloadState;

@end

NS_ASSUME_NONNULL_END
