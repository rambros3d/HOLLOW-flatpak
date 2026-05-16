#import "MacScreenShareAudioTap.h"

#import <CoreAudio/CoreAudio.h>
#import <AppKit/AppKit.h>

#if __has_include(<CoreAudio/AudioHardwareTapping.h>)
#import <CoreAudio/AudioHardwareTapping.h>
#endif

static NSString * const kMacScreenShareAudioTapDomain = @"MacScreenShareAudioTap";

@interface MacScreenShareAudioTap ()
@property(nonatomic) AudioObjectID tapObjectID;
@property(nonatomic) AudioObjectID aggregateDeviceID;
@property(nonatomic, copy, nullable) NSString *originalDefaultInputUID;
@property(nonatomic) BOOL active;
@end

@implementation MacScreenShareAudioTap

+ (instancetype)sharedInstance {
  static MacScreenShareAudioTap *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MacScreenShareAudioTap alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _tapObjectID = kAudioObjectUnknown;
    _aggregateDeviceID = kAudioObjectUnknown;
  }
  return self;
}

#pragma mark - Public

- (BOOL)startWithError:(NSError * _Nullable * _Nullable)error {
  if (self.active) return YES;

  if (@available(macOS 14.2, *)) {
    // Step 1: remember current default input device UID so we can restore it.
    NSString *originalUID = [self currentDefaultInputDeviceUID];
    self.originalDefaultInputUID = originalUID;

    // Step 2: create a process tap that mixes audio from every process
    // except our own. CATapDescription with `processObjectIDs: @[]` plus the
    // `stereoMixdown` style taps everything globally.
    AudioObjectID tapID = kAudioObjectUnknown;
    if (![self createTapWithObjectID:&tapID error:error]) {
      [self stop];
      return NO;
    }
    self.tapObjectID = tapID;

    // Step 3: build an aggregate device combining the user's current default
    // input (their mic) plus the tap. WebRTC's ADM reads from default input,
    // so once we set this aggregate as default, it gets mic + system audio.
    AudioObjectID aggregateID = kAudioObjectUnknown;
    if (![self createAggregateWithMicUID:originalUID
                                  tapID:tapID
                            objectID:&aggregateID
                                  error:error]) {
      [self stop];
      return NO;
    }
    self.aggregateDeviceID = aggregateID;

    // Step 4: switch system default input to the aggregate. Use the
    // AudioObjectID directly — CoreAudio's UID lookup table sometimes
    // doesn't see a freshly-created aggregate yet.
    if (![self setDefaultInputDeviceID:aggregateID error:error]) {
      [self stop];
      return NO;
    }

    self.active = YES;
    return YES;
  }

  if (error) {
    *error = [NSError errorWithDomain:kMacScreenShareAudioTapDomain
                                 code:-1
                             userInfo:@{NSLocalizedDescriptionKey:
                                          @"System audio capture requires macOS 14.2 or later."}];
  }
  return NO;
}

- (void)stop {
  if (@available(macOS 14.2, *)) {
    // Restore original default input first so WebRTC stops reading from the
    // aggregate before we tear it down.
    if (self.originalDefaultInputUID.length > 0) {
      [self setDefaultInputDeviceUID:self.originalDefaultInputUID error:NULL];
      self.originalDefaultInputUID = nil;
    }

    if (self.aggregateDeviceID != kAudioObjectUnknown) {
      AudioHardwareDestroyAggregateDevice(self.aggregateDeviceID);
      self.aggregateDeviceID = kAudioObjectUnknown;
    }

    if (self.tapObjectID != kAudioObjectUnknown) {
      AudioHardwareDestroyProcessTap(self.tapObjectID);
      self.tapObjectID = kAudioObjectUnknown;
    }
  }
  self.active = NO;
}

#pragma mark - CoreAudio helpers

- (BOOL)createTapWithObjectID:(AudioObjectID *)outObjectID
                        error:(NSError **)error API_AVAILABLE(macos(14.2)) {
  CATapDescription *desc = [[CATapDescription alloc] initStereoGlobalTapButExcludeProcesses:@[]];
  desc.muteBehavior = CATapUnmuted;
  desc.exclusive = NO;
  desc.mixdown = YES;
  desc.privateTap = YES;
  desc.name = @"Hollow Screen Share Audio Tap";

  AudioObjectID tapID = kAudioObjectUnknown;
  OSStatus status = AudioHardwareCreateProcessTap(desc, &tapID);
  if (status != noErr || tapID == kAudioObjectUnknown) {
    if (error) {
      *error = [NSError errorWithDomain:kMacScreenShareAudioTapDomain
                                   code:status
                               userInfo:@{NSLocalizedDescriptionKey:
                                            [NSString stringWithFormat:@"AudioHardwareCreateProcessTap failed: %d", (int)status]}];
    }
    return NO;
  }
  *outObjectID = tapID;
  return YES;
}

- (BOOL)createAggregateWithMicUID:(NSString * _Nullable)micUID
                            tapID:(AudioObjectID)tapID
                         objectID:(AudioObjectID *)outObjectID
                            error:(NSError **)error API_AVAILABLE(macos(14.2)) {
  NSString *tapUID = [self uidForTap:tapID];
  if (tapUID == nil) {
    if (error) {
      *error = [NSError errorWithDomain:kMacScreenShareAudioTapDomain
                                   code:-2
                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to read tap UID"}];
    }
    return NO;
  }

  NSMutableArray *subDeviceList = [NSMutableArray array];
  if (micUID.length > 0) {
    [subDeviceList addObject:@{
      @(kAudioSubDeviceUIDKey): micUID,
    }];
  }
  // The tap appears as a subdevice via its UID with the kAudioSubTapUIDKey key.
  [subDeviceList addObject:@{
    @(kAudioSubTapUIDKey): tapUID,
  }];

  NSString *aggregateUID = [NSString stringWithFormat:@"com.anonlisten.hollow.screenshare.%@", [[NSUUID UUID] UUIDString]];

  NSDictionary *aggregateDescription = @{
    @(kAudioAggregateDeviceUIDKey): aggregateUID,
    @(kAudioAggregateDeviceNameKey): @"Hollow Screen Share Mix",
    @(kAudioAggregateDeviceIsPrivateKey): @YES,
    @(kAudioAggregateDeviceIsStackedKey): @NO,
    @(kAudioAggregateDeviceTapListKey): @[
      @{@(kAudioSubTapUIDKey): tapUID},
    ],
    @(kAudioAggregateDeviceSubDeviceListKey): subDeviceList,
  };

  AudioObjectID aggID = kAudioObjectUnknown;
  OSStatus status = AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)aggregateDescription, &aggID);
  if (status != noErr || aggID == kAudioObjectUnknown) {
    if (error) {
      *error = [NSError errorWithDomain:kMacScreenShareAudioTapDomain
                                   code:status
                               userInfo:@{NSLocalizedDescriptionKey:
                                            [NSString stringWithFormat:@"AudioHardwareCreateAggregateDevice failed: %d", (int)status]}];
    }
    return NO;
  }
  *outObjectID = aggID;
  return YES;
}

#pragma mark - CoreAudio property reads/writes

- (NSString * _Nullable)currentDefaultInputDeviceUID {
  AudioObjectID deviceID = kAudioObjectUnknown;
  UInt32 size = sizeof(deviceID);
  AudioObjectPropertyAddress addr = {
    kAudioHardwarePropertyDefaultInputDevice,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceID);
  if (status != noErr || deviceID == kAudioObjectUnknown) {
    return nil;
  }
  return [self deviceUIDForObjectID:deviceID];
}

- (NSString * _Nullable)deviceUIDForObjectID:(AudioObjectID)objectID {
  CFStringRef cfUID = NULL;
  UInt32 size = sizeof(cfUID);
  AudioObjectPropertyAddress addr = {
    kAudioDevicePropertyDeviceUID,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  OSStatus status = AudioObjectGetPropertyData(objectID, &addr, 0, NULL, &size, &cfUID);
  if (status != noErr || cfUID == NULL) {
    return nil;
  }
  NSString *uid = (__bridge_transfer NSString *)cfUID;
  return uid;
}

- (NSString * _Nullable)uidForTap:(AudioObjectID)tapID API_AVAILABLE(macos(14.2)) {
  CFStringRef cfUID = NULL;
  UInt32 size = sizeof(cfUID);
  AudioObjectPropertyAddress addr = {
    kAudioTapPropertyUID,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  OSStatus status = AudioObjectGetPropertyData(tapID, &addr, 0, NULL, &size, &cfUID);
  if (status != noErr || cfUID == NULL) {
    return nil;
  }
  return (__bridge_transfer NSString *)cfUID;
}

- (BOOL)setDefaultInputDeviceUID:(NSString *)uid error:(NSError **)error {
  AudioObjectID targetID = [self objectIDForDeviceUID:uid];
  if (targetID == kAudioObjectUnknown) {
    if (error) {
      *error = [NSError errorWithDomain:kMacScreenShareAudioTapDomain
                                   code:-3
                               userInfo:@{NSLocalizedDescriptionKey:
                                            [NSString stringWithFormat:@"No audio device with UID %@", uid]}];
    }
    return NO;
  }
  return [self setDefaultInputDeviceID:targetID error:error];
}

- (BOOL)setDefaultInputDeviceID:(AudioObjectID)targetID error:(NSError **)error {
  AudioObjectPropertyAddress addr = {
    kAudioHardwarePropertyDefaultInputDevice,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  OSStatus status = AudioObjectSetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL,
                                               sizeof(targetID), &targetID);
  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:kMacScreenShareAudioTapDomain
                                   code:status
                               userInfo:@{NSLocalizedDescriptionKey:
                                            [NSString stringWithFormat:@"Setting default input failed: %d", (int)status]}];
    }
    return NO;
  }
  return YES;
}

- (AudioObjectID)objectIDForDeviceUID:(NSString *)uid {
  AudioObjectID targetID = kAudioObjectUnknown;
  CFStringRef cfUID = (__bridge CFStringRef)uid;
  AudioValueTranslation translation = {
    .mInputData = &cfUID,
    .mInputDataSize = sizeof(cfUID),
    .mOutputData = &targetID,
    .mOutputDataSize = sizeof(targetID),
  };
  UInt32 size = sizeof(translation);
  AudioObjectPropertyAddress addr = {
    kAudioHardwarePropertyDeviceForUID,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &translation);
  return targetID;
}

@end
