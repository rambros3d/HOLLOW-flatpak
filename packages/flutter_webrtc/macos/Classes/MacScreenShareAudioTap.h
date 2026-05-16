#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Captures system audio output on macOS 14.2+ via CoreAudio Process Tap and
/// routes it into WebRTC by:
///  1. Creating a process tap on all running processes (excluding self).
///  2. Combining the user's current default input device + the tap inside a
///     CoreAudio Aggregate Device.
///  3. Temporarily switching the system default input to the aggregate device
///     so WebRTC's ADM picks up mic + system audio mixed.
///
/// On `stop`, the original default input device is restored and the aggregate
/// and tap are destroyed. The class is a singleton — only one screen share
/// audio tap is active at a time.
///
/// Note: switching the system default input device is observable by every
/// process that polls for the current default input, but most apps cache it
/// and won't notice for the duration of the share. This is a known tradeoff
/// of the no-virtual-driver approach.
@interface MacScreenShareAudioTap : NSObject

+ (instancetype)sharedInstance;

/// Activate the tap + aggregate device and switch the system default input
/// to it. Returns YES on success.
- (BOOL)startWithError:(NSError * _Nullable * _Nullable)error;

/// Tear down the tap, destroy the aggregate device, restore the original
/// default input. Safe to call multiple times.
- (void)stop;

/// Whether the tap is currently active.
@property(nonatomic, readonly, getter=isActive) BOOL active;

@end

NS_ASSUME_NONNULL_END
