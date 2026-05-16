#import "MacAudioDevices.h"

#import <CoreAudio/CoreAudio.h>

@implementation MacAudioDevices

+ (NSArray<NSDictionary *> *)inputDevices {
  return [self devicesForScope:kAudioDevicePropertyScopeInput];
}

+ (NSArray<NSDictionary *> *)outputDevices {
  return [self devicesForScope:kAudioDevicePropertyScopeOutput];
}

#pragma mark - Helpers

+ (NSArray<NSDictionary *> *)devicesForScope:(AudioObjectPropertyScope)scope {
  NSMutableArray<NSDictionary *> *out = [NSMutableArray array];

  AudioObjectPropertyAddress listAddr = {
    kAudioHardwarePropertyDevices,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };

  UInt32 dataSize = 0;
  OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                                   &listAddr, 0, NULL, &dataSize);
  if (status != noErr || dataSize == 0) return out;

  UInt32 deviceCount = dataSize / (UInt32)sizeof(AudioObjectID);
  AudioObjectID *deviceIDs = (AudioObjectID *)malloc(dataSize);
  if (deviceIDs == NULL) return out;
  status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &listAddr,
                                      0, NULL, &dataSize, deviceIDs);
  if (status != noErr) {
    free(deviceIDs);
    return out;
  }

  AudioObjectID defaultID = [self defaultDeviceForScope:scope];

  for (UInt32 i = 0; i < deviceCount; i++) {
    AudioObjectID dev = deviceIDs[i];

    if (![self device:dev hasStreamsForScope:scope]) continue;

    NSString *uid = [self stringPropertyOf:dev
                                  selector:kAudioDevicePropertyDeviceUID
                                     scope:kAudioObjectPropertyScopeGlobal];
    NSString *name = [self stringPropertyOf:dev
                                   selector:kAudioObjectPropertyName
                                      scope:kAudioObjectPropertyScopeGlobal];
    if (uid.length == 0) continue;
    if (name.length == 0) name = uid;

    [out addObject:@{
      @"id" : uid,
      @"name" : name,
      @"isInput" : @(scope == kAudioDevicePropertyScopeInput),
      @"isDefault" : @(dev == defaultID),
    }];
  }

  free(deviceIDs);
  return out;
}

+ (BOOL)device:(AudioObjectID)dev hasStreamsForScope:(AudioObjectPropertyScope)scope {
  AudioObjectPropertyAddress addr = {
    kAudioDevicePropertyStreamConfiguration,
    scope,
    kAudioObjectPropertyElementMain,
  };
  UInt32 size = 0;
  OSStatus status = AudioObjectGetPropertyDataSize(dev, &addr, 0, NULL, &size);
  if (status != noErr || size == 0) return NO;

  AudioBufferList *buffers = (AudioBufferList *)malloc(size);
  if (!buffers) return NO;
  status = AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, buffers);
  BOOL hasChannels = NO;
  if (status == noErr) {
    for (UInt32 i = 0; i < buffers->mNumberBuffers; i++) {
      if (buffers->mBuffers[i].mNumberChannels > 0) {
        hasChannels = YES;
        break;
      }
    }
  }
  free(buffers);
  return hasChannels;
}

+ (AudioObjectID)defaultDeviceForScope:(AudioObjectPropertyScope)scope {
  AudioObjectPropertySelector sel =
      (scope == kAudioDevicePropertyScopeInput)
          ? kAudioHardwarePropertyDefaultInputDevice
          : kAudioHardwarePropertyDefaultOutputDevice;
  AudioObjectPropertyAddress addr = {
    sel,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  AudioObjectID dev = kAudioObjectUnknown;
  UInt32 size = sizeof(dev);
  AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &dev);
  return dev;
}

+ (NSString * _Nullable)stringPropertyOf:(AudioObjectID)dev
                                selector:(AudioObjectPropertySelector)selector
                                   scope:(AudioObjectPropertyScope)scope {
  AudioObjectPropertyAddress addr = {
    selector,
    scope,
    kAudioObjectPropertyElementMain,
  };
  CFStringRef cf = NULL;
  UInt32 size = sizeof(cf);
  OSStatus status = AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, &cf);
  if (status != noErr || cf == NULL) return nil;
  return (__bridge_transfer NSString *)cf;
}

@end
