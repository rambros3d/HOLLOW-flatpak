#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// CoreAudio-backed enumeration of macOS audio devices. Used as a substitute
/// for WebRTC-SDK's `RTCAudioDeviceModule.inputDevices/outputDevices`, which
/// returns an empty list on macOS in the version this project pins.
///
/// Each returned dictionary has keys: `id` (NSString, CoreAudio UID),
/// `name` (NSString, human-readable), `isInput` (NSNumber bool),
/// `isDefault` (NSNumber bool).
@interface MacAudioDevices : NSObject

+ (NSArray<NSDictionary *> *)inputDevices;
+ (NSArray<NSDictionary *> *)outputDevices;

@end

NS_ASSUME_NONNULL_END
