//
//  Tweak.x
//  MuteLock - Camera & Microphone Kill Switch
//  By Yousef (@yousef_dev921)
//
//  Three-layer defense:
//  - Layer A: AVFoundation API hooks (UIKit apps)
//  - Layer B: mediaserverd/tccd hooks (system daemons)
//  - Layer C: IOKit + AudioUnit hooks (low-level)
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

#pragma mark - Helpers

static NSString *getCurrentBundleID(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || bundleID.length == 0) {
        bundleID = [[NSProcessInfo processInfo] processName];
    }
    return bundleID;
}

#pragma mark - Block Decision Helpers

static BOOL shouldBlockCameraForBundle(NSString *bundleID) {
    NSString *target = bundleID ?: getCurrentBundleID();
    return [[MuteLockPolicy sharedInstance] shouldBlockCameraForBundleID:target];
}

static BOOL shouldBlockMicForBundle(NSString *bundleID) {
    NSString *target = bundleID ?: getCurrentBundleID();
    return [[MuteLockPolicy sharedInstance] shouldBlockMicrophoneForBundleID:target];
}

static BOOL shouldBlockCameraNow(void) {
    return shouldBlockCameraForBundle(nil);
}

static BOOL shouldBlockMicNow(void) {
    return shouldBlockMicForBundle(nil);
}

static void logCameraBlocked(void) {
    MuteLockLogBlockedAccess(getCurrentBundleID(), @"camera");
}

static void logMicBlocked(void) {
    MuteLockLogBlockedAccess(getCurrentBundleID(), @"microphone");
}

#pragma mark - Layer A: AVFoundation (UIKit Apps)

%group LayerA_AVFoundation

%hook AVCaptureDevice

+ (AVAuthorizationStatus)authorizationStatusForMediaType:(AVMediaType)mediaType {
    if ([mediaType isEqualToString:AVMediaTypeVideo] && shouldBlockCameraNow()) {
        logCameraBlocked();
        return AVAuthorizationStatusDenied;
    }
    if ([mediaType isEqualToString:AVMediaTypeAudio] && shouldBlockMicNow()) {
        logMicBlocked();
        return AVAuthorizationStatusDenied;
    }
    return %orig;
}

+ (void)requestAccessForMediaType:(AVMediaType)mediaType completionHandler:(void (^)(BOOL granted))handler {
    if ([mediaType isEqualToString:AVMediaTypeVideo] && shouldBlockCameraNow()) {
        logCameraBlocked();
        if (handler) dispatch_async(dispatch_get_main_queue(), ^{ handler(NO); });
        return;
    }
    if ([mediaType isEqualToString:AVMediaTypeAudio] && shouldBlockMicNow()) {
        logMicBlocked();
        if (handler) dispatch_async(dispatch_get_main_queue(), ^{ handler(NO); });
        return;
    }
    %orig;
}

+ (NSArray *)devicesWithMediaType:(AVMediaType)mediaType {
    if ([mediaType isEqualToString:AVMediaTypeVideo] && shouldBlockCameraNow()) return @[];
    if ([mediaType isEqualToString:AVMediaTypeAudio] && shouldBlockMicNow()) return @[];
    return %orig;
}

+ (instancetype)defaultDeviceWithMediaType:(AVMediaType)mediaType {
    if ([mediaType isEqualToString:AVMediaTypeVideo] && shouldBlockCameraNow()) return nil;
    if ([mediaType isEqualToString:AVMediaTypeAudio] && shouldBlockMicNow()) return nil;
    return %orig;
}

%end

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
    if (([category isEqualToString:AVAudioSessionCategoryRecord] || [category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) && shouldBlockMicNow()) {
        logMicBlocked();
        if (outError) *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorApplicationIsNotAuthorized userInfo:@{NSLocalizedDescriptionKey: @"Blocked by MuteLock"}];
        return NO;
    }
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

#pragma mark - Layer C: IOKit

static kern_return_t (*orig_IOServiceOpen)(io_service_t service, task_port_t owningTask, uint32_t type, io_connect_t *connect);

static NSString *MLRegistryNameForService(io_service_t service) {
    io_name_t name;
    if (IORegistryEntryGetName(service, name) == KERN_SUCCESS) {
        return [NSString stringWithUTF8String:name];
    }
    return nil;
}

static kern_return_t hook_IOServiceOpen(io_service_t service, task_port_t owningTask, uint32_t type, io_connect_t *connect) {
    if (!orig_IOServiceOpen) return kIOReturnError;
    
    if (!service || service == IO_OBJECT_NULL) {
        return orig_IOServiceOpen(service, owningTask, type, connect);
    }
    
    mach_port_type_t type_info;
    if (mach_port_type(mach_task_self(), service, &type_info) != KERN_SUCCESS) {
        return orig_IOServiceOpen(service, owningTask, type, connect);
    }
    
    @try {
        NSString *registryName = MLRegistryNameForService(service);
        
        if (registryName && MuteLockIsCameraService(registryName)) {
            if (shouldBlockCameraNow()) {
                logCameraBlocked();
                if (connect) *connect = IO_OBJECT_NULL;
                return kIOReturnNotPermitted;
            }
        }
        
        if (registryName && MuteLockIsAudioInputService(registryName)) {
            if (shouldBlockMicNow()) {
                logMicBlocked();
                if (connect) *connect = IO_OBJECT_NULL;
                return kIOReturnNotPermitted;
            }
        }
    } @catch (NSException *e) {
        MLLogAlways(@"IOKit hook exception: %@", e.reason);
    }
    
    return orig_IOServiceOpen(service, owningTask, type, connect);
}

#pragma mark - Layer C: AudioUnit

static OSStatus (*orig_AudioOutputUnitStart)(AudioUnit inUnit);
static OSStatus (*orig_AudioUnitRender)(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static Boolean MLAudioUnitIsVPIO(AudioUnit unit) {
    AudioComponent comp = AudioComponentInstanceGetComponent(unit);
    if (!comp) return false;
    
    AudioComponentDescription desc = {0};
    if (AudioComponentGetDescription(comp, &desc) != noErr) return false;
    return desc.componentSubType == kAudioUnitSubType_VoiceProcessingIO;
}

static Boolean MLAudioUnitInputEnabled(AudioUnit unit) {
    UInt32 enableIO = 0;
    UInt32 size = (UInt32)sizeof(enableIO);
    OSStatus status = AudioUnitGetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, &size);
    return status == noErr && enableIO != 0;
}

static OSStatus hook_AudioOutputUnitStart(AudioUnit inUnit) {
    if (!orig_AudioOutputUnitStart) return kAudio_ParamError;
    
    if (shouldBlockMicNow()) {
        if (MLAudioUnitIsVPIO(inUnit) || MLAudioUnitInputEnabled(inUnit)) {
            logMicBlocked();
            return kAudio_ParamError;
        }
    }
    
    return orig_AudioOutputUnitStart(inUnit);
}

static OSStatus hook_AudioUnitRender(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    if (!orig_AudioUnitRender) return kAudio_ParamError;

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
        return noErr; 
    }
    
    return orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
}

#pragma mark - Constructor

static BOOL shouldInjectInProcess(void) {
    NSString *processName = [[NSProcessInfo processInfo] processName];
    
    // Target specific system daemons involved in media capture
    // Note: tccd removed (TCC hooks don't work), mediaserverd removed (iOS 15+ classes don't exist)
    if ([processName isEqualToString:@"coreaudiod"]) {
        return YES;
    }
    
    // Target all UIKit-based user applications
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
        
        BOOL isUIKitProcess = (NSClassFromString(@"UIApplication") != nil);
        BOOL isCoreAudio = [processName isEqualToString:@"coreaudiod"];
        
        // Layer A: Initialize AVFoundation hooks for application-level constraints
        if (isUIKitProcess) {
            %init(LayerA_AVFoundation);
        }
        
        // Layer C: Initialize IOKit hooks for low-level hardware access control
        if (isCoreAudio || isUIKitProcess) {
            void *ioServiceOpenPtr = dlsym(RTLD_DEFAULT, "IOServiceOpen");
            if (ioServiceOpenPtr) {
                MSHookFunction(ioServiceOpenPtr, (void *)hook_IOServiceOpen, (void **)&orig_IOServiceOpen);
                if (!orig_IOServiceOpen) {
                    MLLogAlways(@"WARNING: IOServiceOpen hook failed - possible PAC issue");
                }
            }
        }
        
        // Layer C: Initialize AudioUnit hooks for raw audio processing interception
        if (isCoreAudio || isUIKitProcess) {
            void *audioOutputUnitStartPtr = dlsym(RTLD_DEFAULT, "AudioOutputUnitStart");
            if (audioOutputUnitStartPtr) {
                MSHookFunction(audioOutputUnitStartPtr, (void *)hook_AudioOutputUnitStart, (void **)&orig_AudioOutputUnitStart);
            }
            void *audioUnitRenderPtr = dlsym(RTLD_DEFAULT, "AudioUnitRender");
            if (audioUnitRenderPtr) {
                MSHookFunction(audioUnitRenderPtr, (void *)hook_AudioUnitRender, (void **)&orig_AudioUnitRender);
            }
        }
        
        MLLogAlways(@"MuteLock ready");
    }
}
