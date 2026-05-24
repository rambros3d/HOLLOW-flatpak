#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

@interface FlutterScreenCaptureKitCapturer : NSObject

- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate;

- (void)startCaptureWithFPS:(NSInteger)fps
                   sourceId:(NSString* _Nullable)sourceId
                      width:(NSInteger)width
                     height:(NSInteger)height
                  onStarted:(void (^)(NSError * _Nullable error))onStarted;

- (void)startWindowCaptureWithFPS:(NSInteger)fps
                         windowID:(CGWindowID)windowID
                            width:(NSInteger)width
                           height:(NSInteger)height
                        onStarted:(void (^)(NSError * _Nullable error))onStarted;

- (void)stopCaptureWithCompletion:(void (^)(void))completion;

@end
