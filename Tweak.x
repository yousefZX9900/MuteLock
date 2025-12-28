//
//  Tweak.x
//  MuteLock
//
//  Created by Yousef on 8/27/2025.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioUnit.h>
#import <mach/mach.h>
#import <IOKit/IOKitLib.h>
#import <notify.h>
#import <dlfcn.h>
#import <substrate.h>

#import "MuteLockCommon.h"
#import "MuteLockPolicy.h"

extern int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);
extern pid_t audit_token_to_pid(audit_token_t token);

#ifndef PROC_PIDPATHINFO_MAXSIZE
#define PROC_PIDPATHINFO_MAXSIZE 1024
#endif

#pragma mark - Cached Blocking State (Zero-Overhead for Audio Hooks)

static BOOL _cachedMicBlocked = NO;
static BOOL _cachedCameraBlocked = NO;

static void MLUpdateCachedBlockingState(void) {
    MuteLockPolicy *policy = [MuteLockPolicy sharedInstance];
    _cachedMicBlocked = [policy shouldBlockMicrophoneForBundleID:nil];
    _cachedCameraBlocked = [policy shouldBlockCameraForBundleID:nil];
}

#pragma mark - Helpers

static NSString *getCurrentBundleID(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || bundleID.length == 0) {
        bundleID = [[NSProcessInfo processInfo] processName];
    }
    return bundleID;
}

#pragma mark - Block Decision Helpers

static BOOL shouldBlockCameraNow(void) {
    return _cachedCameraBlocked;
}

static BOOL shouldBlockMicNow(void) {
    return _cachedMicBlocked;
}

static void logCameraBlocked(void) {
    MuteLockLogBlockedAccess(getCurrentBundleID(), @"camera");
}

static void logMicBlocked(void) {
    MuteLockLogBlockedAccess(getCurrentBundleID(), @"microphone");
}

#pragma mark - Layer A: AVFoundation (UIKit Apps)

%group LayerA_AVFoundation

%hook AVCaptureSession

- (void)startRunning {
    for (AVCaptureInput *input in self.inputs) {
        if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
            AVCaptureDevice *device = ((AVCaptureDeviceInput *)input).device;
            if ([device hasMediaType:AVMediaTypeVideo] && shouldBlockCameraNow()) {
                logCameraBlocked();
                return;
            }
            if ([device hasMediaType:AVMediaTypeAudio] && shouldBlockMicNow()) {
                logMicBlocked();
                return;
            }
        }
    }
    %orig;
}

- (BOOL)canAddInput:(AVCaptureInput *)input {
    if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
        AVCaptureDevice *device = ((AVCaptureDeviceInput *)input).device;
        if ([device hasMediaType:AVMediaTypeVideo] && shouldBlockCameraNow()) return NO;
        if ([device hasMediaType:AVMediaTypeAudio] && shouldBlockMicNow()) return NO;
    }
    return %orig;
}

- (void)addInput:(AVCaptureInput *)input {
    if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
        AVCaptureDevice *device = ((AVCaptureDeviceInput *)input).device;
        if ([device hasMediaType:AVMediaTypeVideo] && shouldBlockCameraNow()) return;
        if ([device hasMediaType:AVMediaTypeAudio] && shouldBlockMicNow()) return;
    }
    %orig;
}

%end

%hook AVAudioSession

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
    // Maintain application compatibility.
    return %orig;
}

- (void)requestRecordPermission:(void (^)(BOOL granted))response {
    if (shouldBlockMicNow()) {
        logMicBlocked();
        if (response) dispatch_async(dispatch_get_main_queue(), ^{ response(NO); });
        return;
    }
    %orig;
}

- (AVAudioSessionRecordPermission)recordPermission {
    if (shouldBlockMicNow()) return AVAudioSessionRecordPermissionDenied;
    return %orig;
}

%end

%hook UIImagePickerController

- (void)viewWillAppear:(BOOL)animated {
    UIImagePickerController *picker = (UIImagePickerController *)self;
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera && shouldBlockCameraNow()) {
        logCameraBlocked();
        [picker dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    %orig;
}

+ (BOOL)isSourceTypeAvailable:(NSInteger)sourceType {
    if (sourceType == 1 && shouldBlockCameraNow()) return NO;
    return %orig;
}

%end

%end



#pragma mark - Layer B: AudioUnit (Low-Level)

static OSStatus (*orig_AudioUnitRender)(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static OSStatus hook_AudioUnitRender(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    if (!orig_AudioUnitRender) return kAudio_ParamError;

    // Capture original stream data.
    OSStatus result = orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    
    // Log silent blocking events (Throttled: Once per session). Input (Microphone)
    if (inBusNumber == 1 && shouldBlockMicNow()) {
        if (ioData) {
            for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
                AudioBuffer *buffer = &ioData->mBuffers[i];
                if (buffer->mData && buffer->mDataByteSize > 0) {
                    memset(buffer->mData, 0, buffer->mDataByteSize);
                }
            }
        }
        if (ioActionFlags) *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;

        static BOOL logged = NO;
        if (!logged) {
            logMicBlocked();
            logged = YES;
        }
    }
    
    return result;
}

#pragma mark - Layer C: Constructor & Extreme Protection

static BOOL shouldInjectInProcess(void) {
    NSString *processName = [[NSProcessInfo processInfo] processName];
    
    // Identify target processes.
        if ([processName isEqualToString:@"coreaudiod"]) {
            return YES;
        }

        // Extreme Protection: Enforce media daemon termination.
        if ([processName isEqualToString:@"mediaserverd"]) {
            NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kMuteLockPrefsPath];
            if ([prefs[kMuteLockAggressiveMode] boolValue]) {
                // Schedule delayed termination.
                MLLogAlways(@"Aggressive Mode: Terminating mediaserverd in 5 seconds...");
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    MLLogAlways(@"Terminating mediaserverd.");
                    exit(0);
                });
            }
            return NO; 
        }
        
        // Target UIKit applications
    if (NSClassFromString(@"UIApplication")) {
        return YES;
    }
    
    return NO;
}

%ctor {
    @autoreleasepool {
        if (!shouldInjectInProcess()) return;
        
        NSString *processName = [[NSProcessInfo processInfo] processName];
        MLLogAlways(@"MuteLock v%@ loading in %@", MUTELOCK_VERSION, processName);
        
        [MuteLockPolicy sharedInstance];
        
        MLUpdateCachedBlockingState();
        
        // Register for state change notifications (zero-overhead cache update)
        static int stateToken, prefsToken;
        notify_register_dispatch(kMuteLockNotifyStateChanged, &stateToken, dispatch_get_main_queue(), ^(int token) {
            MLUpdateCachedBlockingState();
        });
        notify_register_dispatch(kMuteLockNotifyPrefsChanged, &prefsToken, dispatch_get_main_queue(), ^(int token) {
            MLUpdateCachedBlockingState();
        });
        
        BOOL isUIKitProcess = (NSClassFromString(@"UIApplication") != nil);
        BOOL isCoreAudio = [processName isEqualToString:@"coreaudiod"];
        
        // Layer A: Initialize AVFoundation hooks for application-level constraints
        if (isUIKitProcess) {
            %init(LayerA_AVFoundation);
        }
        
        // Layer B: Initialize AudioUnit hooks for raw audio processing interception
        if (isCoreAudio || isUIKitProcess) {
            void *audioUnitRenderPtr = dlsym(RTLD_DEFAULT, "AudioUnitRender");
            if (audioUnitRenderPtr) {
                MSHookFunction(audioUnitRenderPtr, (void *)hook_AudioUnitRender, (void **)&orig_AudioUnitRender);
            }
        }
        
        MLLogAlways(@"MuteLock ready");
    }
}
