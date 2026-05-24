#import "FlutterScreenCaptureKitCapturer.h"

#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>

#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#endif

@interface FlutterScreenCaptureKitCapturer ()
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
<SCStreamOutput>
#endif
@property(nonatomic, strong) RTCVideoCapturer *capturer;
@property(nonatomic, weak) id<RTCVideoCapturerDelegate> delegate;
@property(nonatomic, strong) dispatch_queue_t captureQueue;
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
@property(nonatomic, strong) SCStream *stream;
#endif
@end

@implementation FlutterScreenCaptureKitCapturer

- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _capturer = [[RTCVideoCapturer alloc] initWithDelegate:delegate];
    _captureQueue = dispatch_queue_create("com.iperius.sck.capture", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)startCaptureWithFPS:(NSInteger)fps
                   sourceId:(NSString* _Nullable)sourceId
                      width:(NSInteger)width
                     height:(NSInteger)height
                  onStarted:(void (^)(NSError * _Nullable error))onStarted {
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
  if (@available(macOS 12.3, *)) {
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
      if (error != nil) {
        onStarted(error);
        return;
      }

      SCDisplay *display = [self selectDisplayFromContent:content sourceId:sourceId];
      if (display == nil) {
        NSError *noDisplay = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"No matching display"}];
        onStarted(noDisplay);
        return;
      }

      SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
      [self startStreamWithFilter:filter fps:fps width:width height:height
                    nativeWidth:display.width nativeHeight:display.height
                      onStarted:onStarted];
    }];
    return;
  }
#endif

  NSError *unavailable = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"ScreenCaptureKit not available"}];
  onStarted(unavailable);
}

- (void)startWindowCaptureWithFPS:(NSInteger)fps
                         windowID:(CGWindowID)windowID
                            width:(NSInteger)width
                           height:(NSInteger)height
                        onStarted:(void (^)(NSError * _Nullable error))onStarted {
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
  if (@available(macOS 12.3, *)) {
    [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                             onScreenWindowsOnly:NO
                                               completionHandler:^(SCShareableContent *content, NSError *error) {
      if (error != nil) {
        onStarted(error);
        return;
      }

      SCWindow *targetWindow = nil;
      for (SCWindow *window in content.windows) {
        if (window.windowID == windowID) {
          targetWindow = window;
          break;
        }
      }

      if (targetWindow == nil) {
        NSError *noWindow = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"No matching window"}];
        onStarted(noWindow);
        return;
      }

      SCContentFilter *filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:targetWindow];
      NSInteger nativeW = (NSInteger)targetWindow.frame.size.width;
      NSInteger nativeH = (NSInteger)targetWindow.frame.size.height;
      [self startStreamWithFilter:filter fps:fps width:width height:height
                    nativeWidth:nativeW nativeHeight:nativeH
                      onStarted:onStarted];
    }];
    return;
  }
#endif

  NSError *unavailable = [NSError errorWithDomain:@"FlutterScreenCaptureKit"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"ScreenCaptureKit not available"}];
  onStarted(unavailable);
}

#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
- (void)startStreamWithFilter:(SCContentFilter *)filter
                          fps:(NSInteger)fps
                        width:(NSInteger)width
                       height:(NSInteger)height
                  nativeWidth:(NSInteger)nativeWidth
                 nativeHeight:(NSInteger)nativeHeight
                    onStarted:(void (^)(NSError * _Nullable error))onStarted
    API_AVAILABLE(macos(12.3)) {
  SCStreamConfiguration *config = [SCStreamConfiguration new];
  // Use requested dimensions if provided, otherwise native resolution.
  config.width = (width > 0) ? width : nativeWidth;
  config.height = (height > 0) ? height : nativeHeight;
  config.minimumFrameInterval = CMTimeMake(1, (int32_t)MAX(1, fps));
  config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
  if (@available(macOS 13.0, *)) {
    config.showsCursor = YES;
  }

  self.stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:nil];
  NSError *addOutputError = nil;
  [self.stream addStreamOutput:self
                          type:SCStreamOutputTypeScreen
           sampleHandlerQueue:self.captureQueue
                        error:&addOutputError];
  if (addOutputError != nil) {
    onStarted(addOutputError);
    return;
  }

  [self.stream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
    onStarted(startError);
  }];
}
#endif

- (void)stopCaptureWithCompletion:(void (^)(void))completion {
#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
  if (@available(macOS 12.3, *)) {
    if (self.stream == nil) {
      completion();
      return;
    }
    SCStream *stream = self.stream;
    self.stream = nil;
    [stream stopCaptureWithCompletionHandler:^(__unused NSError * _Nullable error) {
      completion();
    }];
    return;
  }
#endif
  completion();
}

#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
- (SCDisplay *)selectDisplayFromContent:(SCShareableContent *)content
                               sourceId:(NSString *)sourceId API_AVAILABLE(macos(12.3)) {
  if (content.displays.count == 0) {
    return nil;
  }

  if (sourceId != nil && sourceId.length > 0) {
    for (SCDisplay *display in content.displays) {
      if ([[NSString stringWithFormat:@"%u", display.displayID] isEqualToString:sourceId]) {
        return display;
      }
    }
  }

  CGDirectDisplayID mainDisplay = CGMainDisplayID();
  for (SCDisplay *display in content.displays) {
    if (display.displayID == mainDisplay) {
      return display;
    }
  }

  return content.displays.firstObject;
}

- (void)stream:(SCStream *)stream
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        ofType:(SCStreamOutputType)type API_AVAILABLE(macos(12.3)) {
  if (type != SCStreamOutputTypeScreen) {
    return;
  }

  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixelBuffer == nil) {
    return;
  }

  CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
  int64_t timeStampNs = (int64_t)(CMTimeGetSeconds(timestamp) * 1000000000.0);

  id<RTCVideoFrameBuffer> rtcBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
  RTCVideoFrame *frame = [[RTCVideoFrame alloc] initWithBuffer:rtcBuffer
                                                      rotation:RTCVideoRotation_0
                                                   timeStampNs:timeStampNs];
  [self.delegate capturer:self.capturer didCaptureVideoFrame:frame];
}
#endif

@end
