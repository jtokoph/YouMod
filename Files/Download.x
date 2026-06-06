// HUGE thanks to @daisuke1227 for implementing all of this
#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <stdarg.h>
#import <stdlib.h>
#import <YouTubeHeader/YTDefaultSheetController.h>
#import <YouTubeHeader/YTIFormatStream.h>
#import <YouTubeHeader/YTIPlayerResponse.h>
#import <YouTubeHeader/YTPlayerResponse.h>
#import <YouTubeHeader/YTIVideoDetails.h>

#define TweakName @"YouMod"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakName]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

@interface YTDefaultSheetController (YouModDownload)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
@end

@interface YTPlayerViewController (YouModDownload)
- (YTPlayerResponse *)contentPlayerResponse;
@end

@interface YTIPlayerResponse (YouModDownload)
- (id)streamingData;
@end

@interface YTIFormatStream (YouModDownload)
- (NSString *)mimeType;
- (BOOL)hasContentLength;
- (unsigned long long)contentLength;
- (unsigned long long)approxDurationMs;
@end

@interface YTIVideoDetails (YouModDownload)
- (NSString *)title;
- (NSString *)author;
- (NSString *)shortDescription;
@end

static UIImage *YouModIconImage(NSInteger iconType) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIImage *image = [icon iconImageWithColor:[UIColor labelColor]];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface YouModMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle handler:(void (^)(void))handler;
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler;
@end

@implementation YouModMenuItem
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle handler:(void (^)(void))handler {
    return [self itemWithTitle:title subtitle:subtitle icon:nil handler:handler];
}
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler {
    YouModMenuItem *item = [YouModMenuItem new];
    item.title = title;
    item.subtitle = subtitle;
    item.iconImage = icon;
    item.handler = handler;
    return item;
}
@end

@interface YouModMediaFormat : NSObject
@property (nonatomic, strong) id source;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, assign) unsigned long long contentLength;
@property (nonatomic, assign) unsigned long long durationMs;
@property (nonatomic, assign) NSInteger fps;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, assign) id audioTrack;
@end

@implementation YouModMediaFormat
@end

@interface YouModAudioOutputFormat : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *fileExtension;
@property (nonatomic, assign) BOOL passthroughWhenCompatible;
@property (nonatomic, assign) BOOL supported;
@end

@implementation YouModAudioOutputFormat
@end

typedef void (^YouModFileDownloadCompletion)(NSURL *fileURL, NSError *error);
typedef void (^YouModMergeCompletion)(BOOL success, NSError *error);
typedef void (^YouModRangeDownloadProgress)(unsigned long long completedBytes);

@interface YouModDownloadChunk : NSObject
@property (nonatomic, assign) unsigned long long offset;
@property (nonatomic, assign) unsigned long long length;
@property (nonatomic, assign) NSUInteger attempts;
@end

@implementation YouModDownloadChunk
@end

@interface YouModRangeDownloader : NSObject
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, copy) NSDictionary *httpHeaders;
@property (nonatomic, assign) unsigned long long expectedBytes;
@property (nonatomic, copy) YouModRangeDownloadProgress progress;
@property (nonatomic, copy) YouModFileDownloadCompletion completion;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSMutableArray <YouModDownloadChunk *> *pendingChunks;
@property (nonatomic, strong) NSMutableSet <NSURLSessionDataTask *> *tasks;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@property (nonatomic, assign) NSUInteger activeTaskCount;
@property (nonatomic, assign) NSUInteger totalChunkCount;
@property (nonatomic, assign) unsigned long long completedBytes;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL finished;
- (instancetype)initWithURL:(NSURL *)url destinationURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers progress:(YouModRangeDownloadProgress)progress completion:(YouModFileDownloadCompletion)completion;
- (void)start;
- (void)cancel;
@end

@interface YouModDownloadCoordinator : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSURLSessionDataTask *metadataTask;
@property (nonatomic, strong) YouModRangeDownloader *rangeDownloader;
@property (nonatomic, strong) AVAssetExportSession *exporter;
@property (nonatomic, strong) UIAlertController *progressAlert;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) YMDownloadProgressView *progressPill;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) YouModFileDownloadCompletion fileCompletion;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, strong) NSURL *videoTempURL;
@property (nonatomic, strong) NSURL *audioTempURL;
@property (nonatomic, assign) unsigned long long completedBytes;
@property (nonatomic, assign) unsigned long long totalBytes;
@property (nonatomic, assign) unsigned long long currentBytes;
@property (nonatomic, assign) unsigned long long currentExpectedBytes;
@property (nonatomic, assign) BOOL currentResolvedSizeAddedToTotal;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL finishedCurrentFile;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, copy) NSString *baseProgressTitle;
@property (nonatomic, assign) NSTimeInterval downloadStartTime;
+ (instancetype)sharedCoordinator;
- (void)startVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter;
- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter;
- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID outputFormat:(YouModAudioOutputFormat *)outputFormat presenter:(UIViewController *)presenter;
- (void)startDirectVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter;
- (void)startDirectSingleVideoDownloadWithFormat:(YouModMediaFormat *)format fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter;
- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter;
- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID outputFormat:(YouModAudioOutputFormat *)outputFormat presenter:(UIViewController *)presenter;
- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter;
- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError;
- (void)trimSingleVideoURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter;
@end

static const unsigned long long YouModFastDownloadMinimumBytes = 256ULL * 1024ULL;
static const unsigned long long YouModFastDownloadChunkBytes = 4ULL * 1024ULL * 1024ULL;
static const NSUInteger YouModFastDownloadConcurrency = 8;
static const NSUInteger YouModFastDownloadMaxAttempts = 3;

static BOOL YouModHTTPHeadersContainField(NSDictionary *headers, NSString *field) {
    for (id key in headers) {
        if ([key isKindOfClass:NSString.class] && [(NSString *)key caseInsensitiveCompare:field] == NSOrderedSame)
            return YES;
    }
    return NO;
}

static NSString *YouModYouTubeCookiesString(void) {
    NSMutableArray *cookieStrings = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.domain containsString:@"youtube.com"]) {
            [cookieStrings addObject:[NSString stringWithFormat:@"%@=%@", cookie.name, cookie.value]];
        }
    }
    return [cookieStrings componentsJoinedByString:@"; "];
}

static NSString *YouModNativeUserAgent(void) {
    NSString *version = @"21.18.4";
    NSString *sysVersion = [[UIDevice currentDevice].systemVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"] ?: @"18_7";
    return [NSString stringWithFormat:@"com.google.ios.youtube/%@ (iPhone; CPU iPhone OS %@ like Mac OS X)", version, sysVersion];
}

static void YouModApplyDownloadHeaders(NSMutableURLRequest *request, NSDictionary *headers) {
    for (id key in headers) {
        id value = headers[key];
        if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
            [request setValue:value forHTTPHeaderField:key];
    }
    if (!YouModHTTPHeadersContainField(headers, @"User-Agent"))
        [request setValue:YouModNativeUserAgent() forHTTPHeaderField:@"User-Agent"];
    if (!YouModHTTPHeadersContainField(headers, @"Origin"))
        [request setValue:@"https://www.youtube.com" forHTTPHeaderField:@"Origin"];
    if (!YouModHTTPHeadersContainField(headers, @"Referer"))
        [request setValue:@"https://www.youtube.com/" forHTTPHeaderField:@"Referer"];
    if (!YouModHTTPHeadersContainField(headers, @"Cookie")) {
        NSString *cookies = YouModYouTubeCookiesString();
        if (cookies.length > 0) [request setValue:cookies forHTTPHeaderField:@"Cookie"];
    }
    extern NSString *YouModGlobalAuthHeader;
    if (YouModGlobalAuthHeader && !YouModHTTPHeadersContainField(headers, @"Authorization")) {
        [request setValue:YouModGlobalAuthHeader forHTTPHeaderField:@"Authorization"];
    }
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
}

@implementation YouModRangeDownloader

- (instancetype)initWithURL:(NSURL *)url destinationURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers progress:(YouModRangeDownloadProgress)progress completion:(YouModFileDownloadCompletion)completion {
    self = [super init];
    if (self) {
        _url = url;
        _destinationURL = destinationURL;
        _httpHeaders = [headers copy];
        _expectedBytes = expectedBytes;
        _progress = [progress copy];
        _completion = [completion copy];
        _pendingChunks = [NSMutableArray array];
        _tasks = [NSMutableSet set];
        _stateQueue = dispatch_queue_create("com.youmod.download.range.state", DISPATCH_QUEUE_SERIAL);
        _fileQueue = dispatch_queue_create("com.youmod.download.range.file", DISPATCH_QUEUE_SERIAL);

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = YouModFastDownloadConcurrency;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForResource = 300;
        NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
        for (id key in headers) {
            id value = headers[key];
            if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
                additionalHeaders[key] = value;
        }
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"User-Agent"))
            additionalHeaders[@"User-Agent"] = YouModNativeUserAgent();
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"Origin"))
            additionalHeaders[@"Origin"] = @"https://www.youtube.com";
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"Referer"))
            additionalHeaders[@"Referer"] = @"https://www.youtube.com/";
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"Cookie")) {
            NSString *cookies = YouModYouTubeCookiesString();
            if (cookies.length > 0) additionalHeaders[@"Cookie"] = cookies;
        }
        extern NSString *YouModGlobalAuthHeader;
        if (YouModGlobalAuthHeader && !YouModHTTPHeadersContainField(additionalHeaders, @"Authorization")) {
            additionalHeaders[@"Authorization"] = YouModGlobalAuthHeader;
        }
        additionalHeaders[@"Accept-Encoding"] = @"identity";
        configuration.HTTPAdditionalHeaders = additionalHeaders;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:@"YouMod" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Download failed"}];
}

- (BOOL)prepareDestinationWithError:(NSError **)error {
    [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    if (![NSFileManager.defaultManager createFileAtPath:self.destinationURL.path contents:nil attributes:nil]) {
        if (error) *error = [self errorWithCode:20 message:@"Cannot create file"];
        return NO;
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.destinationURL.path];
    if (!self.fileHandle) {
        if (error) *error = [self errorWithCode:21 message:@"Cannot open file"];
        return NO;
    }

    @try {
        [self.fileHandle truncateFileAtOffset:self.expectedBytes];
    } @catch (NSException *exception) {
        if (error) *error = [self errorWithCode:22 message:exception.reason ?: @"Cannot allocate file"];
        return NO;
    }
    return YES;
}

- (void)start {
    dispatch_async(self.stateQueue, ^{
        if (self.expectedBytes == 0) {
            [self finishWithErrorLocked:[self errorWithCode:23 message:@"Unknown stream size"]];
            return;
        }

        NSError *error = nil;
        if (![self prepareDestinationWithError:&error]) {
            [self finishWithErrorLocked:error];
            return;
        }

        unsigned long long chunkSize = self.expectedBytes / YouModFastDownloadConcurrency;
        if (chunkSize < 256ULL * 1024ULL) chunkSize = 256ULL * 1024ULL;
        if (chunkSize > YouModFastDownloadChunkBytes) chunkSize = YouModFastDownloadChunkBytes;

        for (unsigned long long offset = 0; offset < self.expectedBytes; offset += chunkSize) {
            YouModDownloadChunk *chunk = [YouModDownloadChunk new];
            chunk.offset = offset;
            unsigned long long remaining = self.expectedBytes - offset;
            chunk.length = remaining < chunkSize ? remaining : chunkSize;
            [self.pendingChunks addObject:chunk];
        }
        self.totalChunkCount = self.pendingChunks.count;
        [self scheduleChunksLocked];
    });
}

- (void)cancel {
    dispatch_async(self.stateQueue, ^{
        if (self.finished) return;
        self.cancelled = YES;
        self.finished = YES;
        for (NSURLSessionDataTask *task in self.tasks) [task cancel];
        [self.tasks removeAllObjects];
        [self.session invalidateAndCancel];
        dispatch_async(self.fileQueue, ^{
            @try {
                [self.fileHandle closeFile];
            } @catch (__unused NSException *exception) {
            }
            [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
        });
    });
}

- (void)scheduleChunksLocked {
    if (self.finished || self.cancelled) return;
    while (self.activeTaskCount < YouModFastDownloadConcurrency && self.pendingChunks.count > 0) {
        YouModDownloadChunk *chunk = self.pendingChunks.firstObject;
        [self.pendingChunks removeObjectAtIndex:0];
        [self startChunkLocked:chunk];
    }

    if (self.activeTaskCount == 0 && self.pendingChunks.count == 0) {
        [self finishSuccessfullyLocked];
    }
}

- (void)startChunkLocked:(YouModDownloadChunk *)chunk {
    unsigned long long end = chunk.offset + chunk.length - 1;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    YouModApplyDownloadHeaders(request, self.httpHeaders);
    [request setValue:[NSString stringWithFormat:@"bytes=%llu-%llu", chunk.offset, end] forHTTPHeaderField:@"Range"];

    __weak typeof(self) weakSelf = self;
    __block NSURLSessionDataTask *task = nil;
    task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self completeChunk:chunk task:task data:data response:response error:error];
    }];
    [self.tasks addObject:task];
    self.activeTaskCount++;
    [task resume];
}

- (NSError *)validationErrorForChunk:(YouModDownloadChunk *)chunk data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    if (error) return error;

    NSHTTPURLResponse *httpResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
    NSInteger statusCode = httpResponse.statusCode;
    BOOL statusOK = statusCode == 206 || (self.totalChunkCount == 1 && statusCode == 200);
    if (httpResponse && !statusOK)
        return [self errorWithCode:24 message:@"Range request rejected by server"];

    if (data.length != chunk.length)
        return [self errorWithCode:25 message:@"Incomplete chunk"];

    return nil;
}

- (void)completeChunk:(YouModDownloadChunk *)chunk task:(NSURLSessionDataTask *)task data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    dispatch_async(self.stateQueue, ^{
        if (self.activeTaskCount > 0) self.activeTaskCount--;
        if (task) [self.tasks removeObject:task];
        if (self.finished || self.cancelled) return;

        NSError *validationError = [self validationErrorForChunk:chunk data:data response:response error:error];
        if (validationError) {
            if (validationError.code == 24) {
                [self finishWithErrorLocked:validationError];
                return;
            }
            if (chunk.attempts + 1 < YouModFastDownloadMaxAttempts) {
                chunk.attempts++;
                [self.pendingChunks insertObject:chunk atIndex:0];
                [self scheduleChunksLocked];
            } else {
                [self finishWithErrorLocked:validationError];
            }
            return;
        }

        NSData *chunkData = [data copy];
        dispatch_async(self.fileQueue, ^{
            NSError *writeError = nil;
            @try {
                [self.fileHandle seekToFileOffset:chunk.offset];
                [self.fileHandle writeData:chunkData];
            } @catch (NSException *exception) {
                writeError = [self errorWithCode:26 message:exception.reason ?: @"Write failed"];
            }

            dispatch_async(self.stateQueue, ^{
                if (self.finished || self.cancelled) return;
                if (writeError) {
                    [self finishWithErrorLocked:writeError];
                    return;
                }

                self.completedBytes += chunkData.length;
                if (self.progress) {
                    unsigned long long completed = self.completedBytes;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.progress(completed);
                    });
                }
                [self scheduleChunksLocked];
            });
        });
    });
}

- (void)finishSuccessfullyLocked {
    if (self.finished) return;
    self.finished = YES;
    [self.session finishTasksAndInvalidate];
    dispatch_async(self.fileQueue, ^{
        @try {
            [self.fileHandle closeFile];
        } @catch (__unused NSException *exception) {
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(self.destinationURL, nil);
        });
    });
}

- (void)finishWithErrorLocked:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;
    for (NSURLSessionDataTask *task in self.tasks) [task cancel];
    [self.tasks removeAllObjects];
    [self.session invalidateAndCancel];
    dispatch_async(self.fileQueue, ^{
        @try {
            [self.fileHandle closeFile];
        } @catch (__unused NSException *exception) {
        }
        [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(nil, error ?: [self errorWithCode:27 message:@"Download failed"]);
        });
    });
}

@end

static __weak YTPlayerViewController *YouModCurrentPlayerViewController;

void YouModDownloadSetCurrentPlayer(YTPlayerViewController *player) {
    YouModCurrentPlayerViewController = player;
}

static NSString *YouModStringFromSelector(id object, SEL selector) {
    if (!object) return nil;
    id value = nil;
    if ([object respondsToSelector:selector]) {
        value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } else {
        @try {
            value = [object valueForKey:NSStringFromSelector(selector)];
        } @catch (__unused NSException *exception) {
            value = nil;
        }
    }
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSURL.class]) return [(NSURL *)value absoluteString];
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return [value respondsToSelector:@selector(description)] ? [value description] : nil;
}

static id YouModObjectFromSelector(id object, SEL selector) {
    if (!object) return nil;
    if ([object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        return [object valueForKey:NSStringFromSelector(selector)];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static unsigned long long YouModUnsignedLongLongFromSelector(id object, SEL selector) {
    if (!object) return 0;
    if ([object respondsToSelector:selector]) {
        return ((unsigned long long (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        id value = [object valueForKey:NSStringFromSelector(selector)];
        if ([value respondsToSelector:@selector(unsignedLongLongValue)])
            return [value unsignedLongLongValue];
    } @catch (__unused NSException *exception) {
    }
    return 0;
}

static BOOL YouModBoolFromSelector(id object, SEL selector) {
    if (!object) return NO;
    if ([object respondsToSelector:selector]) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        id value = [object valueForKey:NSStringFromSelector(selector)];
        if ([value respondsToSelector:@selector(boolValue)])
            return [value boolValue];
    } @catch (__unused NSException *exception) {
    }
    return NO;
}

static NSInteger YouModIntegerFromSelector(id object, SEL selector) {
    if (!object) return 0;
    if ([object respondsToSelector:selector]) {
        return ((NSInteger (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        id value = [object valueForKey:NSStringFromSelector(selector)];
        if ([value respondsToSelector:@selector(integerValue)])
            return [value integerValue];
    } @catch (__unused NSException *exception) {
    }
    return 0;
}

static UIViewController *YouModTopViewController(UIViewController *root) {
    if (!root) {
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        root = keyWindow.rootViewController;
    }
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:UINavigationController.class])
        return YouModTopViewController(((UINavigationController *)root).topViewController);
    if ([root isKindOfClass:UITabBarController.class])
        return YouModTopViewController(((UITabBarController *)root).selectedViewController);
    return root;
}

static void YouModSendToast(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showInView:parent message:message buttonTitle:nil action:nil duration:3.0];
}

static void YouModSendSuccess(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showSuccessInView:parent message:message duration:3.0];
}

static void YouModSendError(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showErrorInView:parent message:message duration:4.0];
}

static NSString *YouModByteCount(unsigned long long bytes) {
    if (bytes == 0) return nil;
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:(long long)bytes];
}

static NSString *YouModURLStringBypassingThrottle(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (components) {
        NSMutableArray *queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSURLQueryItem *item in queryItems) {
            if (![item.name isEqualToString:@"n"])
                [filtered addObject:item];
        }
        BOOL hasRateBypass = NO;
        for (NSURLQueryItem *item in filtered) {
            if ([item.name isEqualToString:@"ratebypass"]) { hasRateBypass = YES; break; }
        }
        if (!hasRateBypass)
            [filtered addObject:[NSURLQueryItem queryItemWithName:@"ratebypass" value:@"yes"]];
        components.queryItems = filtered;
        NSString *result = components.string;
        if (result.length > 0) return result;
    }
    return urlString;
}

static NSString *YouModURLStringWithCPN(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    urlString = YouModURLStringBypassingThrottle(urlString);
    if ([urlString containsString:@"cpn="]) return urlString;
    Class ytDataUtils = NSClassFromString(@"YTDataUtils");
    NSString *cpn = ((id (*)(Class, SEL))objc_msgSend)(ytDataUtils, @selector(generateClientSideNonce));
    NSString *separator = [urlString containsString:@"?"] ? @"&" : @"?";
    return [NSString stringWithFormat:@"%@%@cpn=%@", urlString, separator, cpn];
}

static NSString *YouModSanitizedFileName(NSString *name) {
    if (name.length == 0) return @"YouTube Video";
    NSMutableCharacterSet *invalid = [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [invalid formUnionWithCharacterSet:NSCharacterSet.newlineCharacterSet];
    NSArray *parts = [name componentsSeparatedByCharactersInSet:invalid];
    NSString *clean = [[parts componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([clean containsString:@"  "]) clean = [clean stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    if (clean.length > 120) clean = [clean substringToIndex:120];
    return clean.length ? clean : @"YouTube Video";
}

static NSURL *YouModDownloadsDirectoryURL(void) {
    NSURL *documentsURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *downloadsURL = [documentsURL URLByAppendingPathComponent:@"YouMod_Downloads" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:downloadsURL withIntermediateDirectories:YES attributes:nil error:nil];
    return downloadsURL;
}

static NSURL *YouModUniqueFileURL(NSString *fileName, NSString *extension) {
    NSString *safeName = YouModSanitizedFileName(fileName);
    NSURL *directoryURL = YouModDownloadsDirectoryURL();
    NSURL *candidate = [directoryURL URLByAppendingPathComponent:[safeName stringByAppendingPathExtension:extension]];
    NSUInteger index = 2;
    while ([NSFileManager.defaultManager fileExistsAtPath:candidate.path]) {
        NSString *indexed = [NSString stringWithFormat:@"%@ %lu", safeName, (unsigned long)index++];
        candidate = [directoryURL URLByAppendingPathComponent:[indexed stringByAppendingPathExtension:extension]];
    }
    return candidate;
}

static NSURL *YouModTemporaryFileURL(NSString *extension) {
    NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:extension];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static NSInteger YouModResolutionFromQuality(NSString *quality);
static NSInteger YouModFPSFromQuality(NSString *quality);
static NSInteger YouModNormalizedFPS(NSInteger fps);

static unsigned long long YouModDurationMsForURL(NSURL *url) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (!CMTIME_IS_NUMERIC(asset.duration) || !CMTIME_IS_VALID(asset.duration)) return 0;
    Float64 seconds = CMTimeGetSeconds(asset.duration);
    if (!isfinite(seconds) || seconds <= 0.0) return 0;
    return (unsigned long long)llround(seconds * 1000.0);
}

static BOOL YouModCMTimeIsUsable(CMTime time) {
    if (!CMTIME_IS_VALID(time) || !CMTIME_IS_NUMERIC(time) || CMTIME_IS_INDEFINITE(time)) return NO;
    Float64 seconds = CMTimeGetSeconds(time);
    return isfinite(seconds) && seconds > 0.0;
}

static CMTime YouModMinUsableDuration(CMTime first, CMTime second) {
    BOOL firstOK = YouModCMTimeIsUsable(first);
    BOOL secondOK = YouModCMTimeIsUsable(second);
    if (firstOK && secondOK) return CMTIME_COMPARE_INLINE(first, <, second) ? first : second;
    if (firstOK) return first;
    if (secondOK) return second;
    return kCMTimeInvalid;
}

static CMTime YouModExportDuration(AVAsset *videoAsset, AVAsset *audioAsset, unsigned long long expectedDurationMs) {
    CMTime duration = kCMTimeInvalid;
    if (expectedDurationMs > 0)
        duration = CMTimeMakeWithSeconds((double)expectedDurationMs / 1000.0, 600);

    CMTime videoDuration = YouModMinUsableDuration(videoAsset.duration, [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject].timeRange.duration);
    CMTime audioDuration = audioAsset ? YouModMinUsableDuration(audioAsset.duration, [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject].timeRange.duration) : kCMTimeInvalid;
    CMTime mediaDuration = audioAsset ? YouModMinUsableDuration(videoDuration, audioDuration) : videoDuration;

    if (!YouModCMTimeIsUsable(duration)) return mediaDuration;
    if (YouModCMTimeIsUsable(mediaDuration) && CMTIME_COMPARE_INLINE(duration, >, mediaDuration))
        return mediaDuration;
    return duration;
}

static BOOL YouModPathExtensionIsPhotosVideo(NSString *extension) {
    NSString *lower = extension.lowercaseString;
    return [@[@"mp4"] containsObject:lower];
}

static NSString *YouModMimeDetail(NSString *mimeType) {
    NSString *lower = mimeType.lowercaseString;
    if ([lower containsString:@"mp4"]) return @"MP4";
    return mimeType;
}

static NSString *YouModFileExtensionForFormat(YouModMediaFormat *format) {
    NSString *lower = format.mimeType.lowercaseString;
    if ([lower containsString:@"m4a"]) return @"m4a";
    if ([lower containsString:@"mp4"]) return @"mp4";
    return nil;
}

static BOOL YouModFormatLooksMP4Family(YouModMediaFormat *format) {
    NSString *mime = format.mimeType.lowercaseString;
    NSString *extension = YouModFileExtensionForFormat(format);
    return [mime containsString:@"mp4"] || [mime containsString:@"m4a"] || [@[@"mp4", @"m4a"] containsObject:extension];
}

static NSString *YouModMergedVideoOutputExtension(YouModMediaFormat *videoFormat, YouModMediaFormat *audioFormat) {
    if (YouModFormatLooksMP4Family(videoFormat) && YouModFormatLooksMP4Family(audioFormat)) return @"mp4";
    return nil;
}

static BOOL YouModVideoFileCanUseAVFoundation(NSURL *fileURL) {
    return YouModPathExtensionIsPhotosVideo(fileURL.pathExtension);
}

static BOOL YouModVideoFileCanSaveToPhotos(NSURL *fileURL) {
    return YouModPathExtensionIsPhotosVideo(fileURL.pathExtension);
}

static YouModAudioOutputFormat *YouModAudioOutputFormatMake(NSString *identifier, NSString *title, NSString *subtitle, NSString *fileExtension, BOOL passthroughWhenCompatible, BOOL supported) {
    YouModAudioOutputFormat *format = [YouModAudioOutputFormat new];
    format.identifier = identifier;
    format.title = title;
    format.subtitle = subtitle;
    format.fileExtension = fileExtension;
    format.passthroughWhenCompatible = passthroughWhenCompatible;
    format.supported = supported;
    return format;
}

static NSArray <YouModAudioOutputFormat *> *YouModAudioOutputFormats(void) {
    static NSArray <YouModAudioOutputFormat *> *formats = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formats = @[
            YouModAudioOutputFormatMake(@"m4a", @"M4A", @"", @"m4a", YES, YES),
        ];
    });
    return formats;
}

static YouModAudioOutputFormat *YouModDefaultAudioOutputFormat(void) {
    return [YouModAudioOutputFormats() firstObject];
}

static NSString *YouModFormatSubtitle(YouModMediaFormat *format) {
    NSMutableArray *parts = [NSMutableArray array];
    NSString *detail = YouModMimeDetail(format.mimeType);
    if (detail.length) [parts addObject:detail];
    NSString *size = YouModByteCount(format.contentLength);
    if (size.length) [parts addObject:size];
    return [parts componentsJoinedByString:@" - "];
}

static NSString *YouModVideoIDForPlayer(YTPlayerViewController *player) {
    return [player currentVideoID];
}

static id YouModPlayerResponsesForPlayer(YTPlayerViewController *player) {
    id response = YouModObjectFromSelector(player, @selector(contentPlayerResponse));
    if (response == nil) response = YouModObjectFromSelector(player, @selector(playerResponse));
    return response;
}

static NSArray *YouModCaptionTracksForPlayer(YTPlayerViewController *player) {
    id response = YouModPlayerResponsesForPlayer(player);
    id playerData = YouModObjectFromSelector(response, @selector(playerData));
    id captions = YouModObjectFromSelector(playerData, @selector(captions));
    id tracklistRenderer = YouModObjectFromSelector(captions, @selector(playerCaptionsTracklistRenderer));
    NSArray *tracks = YouModObjectFromSelector(tracklistRenderer, @selector(captionTracksArray));
    if (tracks.count > 0) return tracks;
    return nil;
}

static id YouModPlayerDataForPlayer(YTPlayerViewController *player) {
    id response = YouModPlayerResponsesForPlayer(player);
    id playerData = YouModObjectFromSelector(response, @selector(playerData));
    return playerData;
}

static NSString *YouModTitleForPlayer(YTPlayerViewController *player) {
    id playerData = YouModPlayerDataForPlayer(player);
    id details = YouModObjectFromSelector(playerData, @selector(videoDetails));
    NSString *title = YouModStringFromSelector(details, @selector(title));
    NSString *author = YouModStringFromSelector(details, @selector(author));
    // Can add description if uses details.shortDescription
    return [NSString stringWithFormat:@"%@ - %@", author, title];
}

static NSArray *YouModAdaptiveFormatObjectsForPlayer(YTPlayerViewController *player) {
    NSMutableArray *formats = [NSMutableArray array];
    NSMutableSet *seenPointers = [NSMutableSet set];

    void (^appendFormats)(NSArray *) = ^(NSArray *candidateFormats) {
        if (![candidateFormats isKindOfClass:NSArray.class]) return;
        for (id format in candidateFormats) {
            NSString *key = [NSString stringWithFormat:@"%p", format];
            if ([seenPointers containsObject:key]) continue;
            [seenPointers addObject:key];
            [formats addObject:format];
        }
    };

    id response = YouModPlayerResponsesForPlayer(player);
    id playerData = YouModObjectFromSelector(response, @selector(playerData));
    id responseStreamingData = YouModObjectFromSelector(playerData, @selector(streamingData));
    appendFormats(YouModObjectFromSelector(responseStreamingData, @selector(adaptiveFormatsArray)));

    return formats.copy;
}

static YouModMediaFormat *YouModMediaFormatFromStream(id stream, BOOL video) {
    NSString *url = YouModStringFromSelector(stream, @selector(URL));
    NSString *mimeType = YouModStringFromSelector(stream, @selector(mimeType));
    NSString *lowerMime = mimeType.lowercaseString;
    NSInteger itag = YouModIntegerFromSelector(stream, @selector(itag));

    NSSet *mp4VideoItags = [NSSet setWithObjects:@18, @22, @37, @38, @59, @78, @133, @134, @135, @136, @137, @160, @212, @264, @266, @298, @299, nil];
    NSSet *m4aAudioItags = [NSSet setWithObjects:@139, @140, @141, @256, @258, @325, @328, nil];
    BOOL itagMatches = video ? [mp4VideoItags containsObject:@(itag)] : [m4aAudioItags containsObject:@(itag)];
    BOOL typeMatches = video ? ([lowerMime containsString:@"video/"] || itagMatches) : ([lowerMime containsString:@"audio/"] || itagMatches);
    if (!typeMatches) return nil;

    BOOL mimeLooksMP4 = [lowerMime containsString:@"mp4"] || [lowerMime containsString:@"m4a"];
    if (mimeType.length && !mimeLooksMP4 && !itagMatches) return nil;

    YouModMediaFormat *format = [YouModMediaFormat new];
    format.source = stream;
    format.video = video;
    format.urlString = YouModURLStringWithCPN(url);
    format.mimeType = mimeType;
    NSInteger height = YouModIntegerFromSelector(stream, @selector(height));
    NSInteger fps = YouModIntegerFromSelector(stream, @selector(fps));
    fps = YouModNormalizedFPS(fps);
    if (video && (height > 1080 || height < 144 || fps < 30)) return nil;
    format.fps = fps;
    format.qualityLabel = YouModStringFromSelector(stream, @selector(qualityLabel));
    if (!video) {
        NSMutableArray *audioTraits = [NSMutableArray array];
        id audio = YouModObjectFromSelector(stream, @selector(audioTrack));
        if (audio) {
            NSString *audioidp = YouModStringFromSelector(audio, @selector(id_p)); 
            if ([audioidp hasSuffix:@".4"]) [audioTraits addObject:audioidp];
        }
        format.audioTrack = audioTraits;
    }
    if (YouModBoolFromSelector(stream, @selector(hasContentLength))) {
        format.contentLength = YouModUnsignedLongLongFromSelector(stream, @selector(contentLength));
    }
    format.durationMs = YouModUnsignedLongLongFromSelector(stream, @selector(approxDurationMs));
    return format;
}

static NSInteger YouModResolutionFromQuality(NSString *quality) {
    NSScanner *scanner = [NSScanner scannerWithString:quality];
    NSInteger value = 0;
    [scanner scanInteger:&value];
    return value;
}

static NSInteger YouModFPSFromQuality(NSString *quality) {
    NSString *lower = quality.lowercaseString;
    NSRange pRange = [lower rangeOfString:@"p"];
    if (pRange.location != NSNotFound && pRange.location + 1 < lower.length) {
        NSString *afterP = [lower substringFromIndex:pRange.location + 1];
        NSScanner *scanner = [NSScanner scannerWithString:afterP];
        NSInteger fps = 0;
        if ([scanner scanInteger:&fps] && fps > 0) return fps;
    }
    if ([lower containsString:@"60"]) return 60;
    if ([lower containsString:@"50"]) return 50;
    if ([lower containsString:@"30"]) return 30;
    return 0;
}

static NSInteger YouModNormalizedFPS(NSInteger fps) {
    if (fps >= 51 && fps <= 61) return 60;
    if (fps >= 41 && fps <= 51) return 50;
    if (fps >= 24 && fps <= 31) return 30;
    return fps;
}

static NSArray <YouModMediaFormat *> *YouModFormatsForPlayer(YTPlayerViewController *player, BOOL video) {
    NSMutableArray *formats = [NSMutableArray array];
    for (id stream in YouModAdaptiveFormatObjectsForPlayer(player)) {
        YouModMediaFormat *format = YouModMediaFormatFromStream(stream, video);
        if (format) [formats addObject:format];
    }

    [formats sortUsingComparator:^NSComparisonResult(YouModMediaFormat *left, YouModMediaFormat *right) {
        if (video) {
            NSInteger leftRes = YouModResolutionFromQuality(left.qualityLabel);
            NSInteger rightRes = YouModResolutionFromQuality(right.qualityLabel);
            if (leftRes != rightRes) return leftRes > rightRes ? NSOrderedAscending : NSOrderedDescending;
            NSInteger leftFPS = left.fps ?: YouModFPSFromQuality(left.qualityLabel);
            NSInteger rightFPS = right.fps ?: YouModFPSFromQuality(right.qualityLabel);
            if (leftFPS != rightFPS) return leftFPS > rightFPS ? NSOrderedAscending : NSOrderedDescending;
        }
        
        BOOL leftMP4 = YouModFormatLooksMP4Family(left);
        BOOL rightMP4 = YouModFormatLooksMP4Family(right);
        if (leftMP4 != rightMP4) return leftMP4 ? NSOrderedAscending : NSOrderedDescending;
        
        if (!video) return left.audioTrack;
        if (left.contentLength != right.contentLength)
            return left.contentLength > right.contentLength ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSMutableArray *unique = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (YouModMediaFormat *format in formats) {
        NSInteger fps = format.fps ?: YouModFPSFromQuality(format.qualityLabel);
        NSString *key = video
            ? [NSString stringWithFormat:@"%@-%ld-%@", format.qualityLabel, (long)fps, YouModMimeDetail(format.mimeType)]
            : [NSString stringWithFormat:@"%@-%@-%@", format.qualityLabel, format.audioTrack, YouModMimeDetail(format.mimeType)];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [unique addObject:format];
    }
    return unique.copy;
}

static YouModMediaFormat *YouModBestAudioFormatForPlayer(YTPlayerViewController *player) {
    NSArray <YouModMediaFormat *> *audioFormats = YouModFormatsForPlayer(player, NO);
    return audioFormats.firstObject;
}

static UIViewController *YouModPresenterForSender(UIView *sender, YTPlayerViewController *player) {
    UIViewController *presenter = nil;
    if ([sender respondsToSelector:@selector(_viewControllerForAncestor)])
        presenter = [sender _viewControllerForAncestor];
    if (!presenter) presenter = player;
    return YouModTopViewController(presenter);
}

static YTPlayerViewController *YouModPlayerFromViewController(UIViewController *vc) {
    Class playerClass = NSClassFromString(@"YTPlayerViewController");
    UIViewController *cursor = vc;
    while (cursor) {
        if (playerClass && [cursor isKindOfClass:playerClass]) return (YTPlayerViewController *)cursor;
        id player = YouModObjectFromSelector(cursor, @selector(playerViewController));
        if (playerClass && [player isKindOfClass:playerClass]) return (YTPlayerViewController *)player;
        cursor = cursor.parentViewController;
    }
    return YouModCurrentPlayerViewController;
}

static NSURL *YouModThumbnailURLForVideoID(NSString *videoID) {
    if (videoID.length == 0) return nil;
    NSString *urlString = [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/maxresdefault.jpg", videoID];
    return [NSURL URLWithString:urlString];
}

static void YouModRequestPhotoAccess(void (^completion)(BOOL granted)) {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        completion(status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited);
    }];
}

static void YouModSaveVideoToPhotos(NSURL *fileURL, UIViewController *presenter, void (^completion)(BOOL success, NSError *error)) {
    YouModRequestPhotoAccess(^(BOOL granted) {
        if (!granted) {
            NSError *error = [NSError errorWithDomain:@"YouMod" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Photos access denied"}];
            completion(NO, error);
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }];
    });
}

static void YouModShareFile(NSURL *fileURL, UIViewController *presenter) {
    if (!fileURL || !presenter) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    // Fix for iPad and specific presentation alignment
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activity.popoverPresentationController.sourceView = presenter.view;
        // Position at the bottom center of the screen
        activity.popoverPresentationController.sourceRect = CGRectMake(presenter.view.bounds.size.width / 2, presenter.view.bounds.size.height, 0, 0);
        activity.popoverPresentationController.permittedArrowDirections = 0; // No arrow pointing to a button
    } else {
        // On iPhone, UIActivityViewController naturally comes from the bottom center
        activity.popoverPresentationController.sourceView = presenter.view;
    }
    [presenter presentViewController:activity animated:YES completion:nil];
}

static void YouModPresentMenu(NSString *title, NSArray <YouModMenuItem *> *items, UIViewController *presenter, UIView *sender) {
    presenter = YouModTopViewController(presenter);
    Class sheetClass = NSClassFromString(@"YTDefaultSheetController");
    if (sheetClass && [sheetClass respondsToSelector:@selector(sheetControllerWithParentResponder:)]) {
        YTDefaultSheetController *sheet = [sheetClass sheetControllerWithParentResponder:presenter];
        Class actionClass = NSClassFromString(@"YTActionSheetAction");
        for (YouModMenuItem *item in items) {
            id action = nil;
            if ([actionClass respondsToSelector:@selector(actionWithTitle:subtitle:iconImage:handler:)]) {
                action = ((id (*)(Class, SEL, NSString *, NSString *, UIImage *, id))objc_msgSend)(actionClass, @selector(actionWithTitle:subtitle:iconImage:handler:), item.title, item.subtitle, item.iconImage, ^(__unused id action) {
                    if (item.handler) item.handler();
                });
            } else {
                action = ((id (*)(Class, SEL, NSString *, NSInteger, id))objc_msgSend)(actionClass, @selector(actionWithTitle:style:handler:), item.title, 0, ^(__unused id action) {
                    if (item.handler) item.handler();
                });
            }
            if (action) [sheet addAction:action];
        }
        if (sender && [sheet respondsToSelector:@selector(presentFromView:animated:completion:)])
            [sheet presentFromView:sender animated:YES completion:nil];
        else
            [sheet presentFromViewController:presenter animated:YES completion:nil];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (YouModMenuItem *item in items) {
        NSString *rowTitle = item.subtitle.length ? [NSString stringWithFormat:@"%@\n%@", item.title, item.subtitle] : item.title;
        [alert addAction:[UIAlertAction actionWithTitle:rowTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            if (item.handler) item.handler();
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = sender ?: presenter.view;
    [presenter presentViewController:alert animated:YES completion:nil];
}

@implementation YouModDownloadCoordinator

+ (instancetype)sharedCoordinator {
    static YouModDownloadCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinator = [YouModDownloadCoordinator new];
    });
    return coordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPAdditionalHeaders = @{
            @"User-Agent": @"Mozilla/5.0",
            @"Origin": @"https://www.youtube.com",
            @"Referer": @"https://www.youtube.com/",
        };
        configuration.HTTPMaximumConnectionsPerHost = YouModFastDownloadConcurrency;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForResource = 300;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)showProgressWithTitle:(NSString *)title presenter:(UIViewController *)presenter {
    self.presenter = presenter;
    self.baseProgressTitle = title;
    self.downloadStartTime = [NSDate timeIntervalSinceReferenceDate];

    UIView *pillParent = sbGetNotificationParent();
    if (pillParent) {
        __weak typeof(self) weakSelf = self;
        self.progressPill = [YMDownloadProgressView showInView:pillParent
            message:[NSString stringWithFormat:@"%@ - 0%%", title]
            cancelAction:^{
                [weakSelf cancelWithMessage:LOC(@"DOWNLOAD_CANCELLED")];
            }];
    } else {
        self.progressAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ - 0%%", title] message:@"\n" preferredStyle:UIAlertControllerStyleAlert];
        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.progress = 0.0;
        self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.progressAlert.view addSubview:self.progressView];
        [NSLayoutConstraint activateConstraints:@[
            [self.progressView.leadingAnchor constraintEqualToAnchor:self.progressAlert.view.leadingAnchor constant:24.0],
            [self.progressView.trailingAnchor constraintEqualToAnchor:self.progressAlert.view.trailingAnchor constant:-24.0],
            [self.progressView.bottomAnchor constraintEqualToAnchor:self.progressAlert.view.bottomAnchor constant:-56.0],
        ]];
        __weak typeof(self) weakSelf = self;
        [self.progressAlert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
            [weakSelf cancelWithMessage:LOC(@"DOWNLOAD_CANCELLED")];
        }]];
        [presenter presentViewController:self.progressAlert animated:YES completion:nil];
    }
}

- (void)updateProgressTitle:(NSString *)title progress:(float)progress {
    NSString *displayTitle = [NSString stringWithFormat:@"%@ - %ld%%", title, (long)lrintf(progress * 100.0f)];
    if (self.progressPill) {
        [self.progressPill updateProgress:progress title:displayTitle subtitle:nil];
    } else {
        self.progressAlert.title = displayTitle;
        self.progressAlert.message = @"\n";
        [self.progressView setProgress:progress animated:YES];
    }
}

- (void)cancelWithMessage:(NSString *)message {
    [self.task cancel];
    [self.metadataTask cancel];
    [self.rangeDownloader cancel];
    [self.exporter cancelExport];
    self.task = nil;
    self.metadataTask = nil;
    self.rangeDownloader = nil;
    self.exporter = nil;
    self.fileCompletion = nil;
    self.active = NO;
    self.cancelled = YES;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    if (self.progressAlert) { [self.progressAlert dismissViewControllerAnimated:YES completion:nil]; self.progressAlert = nil; self.progressView = nil; }
    [self cleanupTemporaryFiles];
    if (message.length) YouModSendError(message);
}

- (void)cleanupTemporaryFiles {
    if (self.videoTempURL) [NSFileManager.defaultManager removeItemAtURL:self.videoTempURL error:nil];
    if (self.audioTempURL) [NSFileManager.defaultManager removeItemAtURL:self.audioTempURL error:nil];
    self.videoTempURL = nil;
    self.audioTempURL = nil;
}

- (void)downloadURL:(NSURL *)url toURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers completion:(YouModFileDownloadCompletion)completion {
    self.currentResolvedSizeAddedToTotal = NO;
    self.currentExpectedBytes = expectedBytes;
    self.currentBytes = 0;
    if (expectedBytes == 0) {
        __weak typeof(self) weakSelf = self;
        [self resolveExpectedBytesForURL:url headers:headers completion:^(unsigned long long bytes) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (bytes > 0) [self adjustCurrentExpectedBytesIfNeeded:bytes];
            [self beginDownloadURL:url toURL:destinationURL expectedBytes:bytes headers:headers allowFast:YES completion:completion];
        }];
        return;
    }
    [self beginDownloadURL:url toURL:destinationURL expectedBytes:expectedBytes headers:headers allowFast:YES completion:completion];
}

- (void)beginDownloadURL:(NSURL *)url toURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers allowFast:(BOOL)allowFast completion:(YouModFileDownloadCompletion)completion {
    self.destinationURL = destinationURL;
    self.currentExpectedBytes = expectedBytes;
    self.currentBytes = 0;
    self.finishedCurrentFile = NO;
    self.fileCompletion = completion;
    [NSFileManager.defaultManager removeItemAtURL:destinationURL error:nil];

    if (self.cancelled) {
        if (completion) completion(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_CANCELLED")}]);
        return;
    }

    if (allowFast && expectedBytes == 0) allowFast = NO;

    if (allowFast && expectedBytes >= YouModFastDownloadMinimumBytes) {
        __weak typeof(self) weakSelf = self;
        self.rangeDownloader = [[YouModRangeDownloader alloc] initWithURL:url destinationURL:destinationURL expectedBytes:expectedBytes headers:headers progress:^(unsigned long long completedBytes) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            self.currentBytes = completedBytes;
            [self updateDownloadProgressWithCurrentBytes:completedBytes expectedBytes:expectedBytes];
        } completion:^(NSURL *fileURL, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            self.rangeDownloader = nil;
            if (error) {
                [self beginDownloadURL:url toURL:destinationURL expectedBytes:expectedBytes headers:headers allowFast:NO completion:completion];
                return;
            }
            if (completion) completion(fileURL, nil);
        }];
        [self.rangeDownloader start];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    YouModApplyDownloadHeaders(request, headers);
    self.task = [self.session downloadTaskWithRequest:request];
    [self.task resume];
}

- (void)resolveExpectedBytesForURL:(NSURL *)url headers:(NSDictionary *)headers completion:(void (^)(unsigned long long bytes))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    request.HTTPMethod = @"HEAD";
    YouModApplyDownloadHeaders(request, headers);

    __weak typeof(self) weakSelf = self;
    self.metadataTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, __unused NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        unsigned long long bytes = 0;
        if (response.expectedContentLength > 0) {
            bytes = (unsigned long long)response.expectedContentLength;
        } else if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            id header = ((NSHTTPURLResponse *)response).allHeaderFields[@"Content-Length"];
            if ([header respondsToSelector:@selector(unsignedLongLongValue)])
                bytes = [header unsignedLongLongValue];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.metadataTask = nil;
            completion(bytes);
        });
    }];
    [self.metadataTask resume];
}

- (void)updateDownloadProgressWithCurrentBytes:(unsigned long long)currentBytes expectedBytes:(unsigned long long)expectedBytes {
    unsigned long long total = self.totalBytes ?: expectedBytes;
    float progress = total ? (float)(self.completedBytes + currentBytes) / (float)total : 0.0f;
    progress = fminf(fmaxf(progress, 0.0f), 0.985f);

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval elapsed = now - self.downloadStartTime;
    double speedMBps = 0;
    if (elapsed > 0) {
        speedMBps = ((double)(self.completedBytes + currentBytes) / 1048576.0) / elapsed;
    }
    double totalMB = (double)total / 1048576.0;

    NSString *title = [NSString stringWithFormat:@"%@ - %ld%%", self.baseProgressTitle ?: @"Downloading", (long)lrintf(progress * 100.0f)];
    NSString *subtitle;
    if (total > 0) {
        subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f MB", speedMBps, totalMB];
    } else {
        subtitle = [NSString stringWithFormat:@"%.1f MB/s", speedMBps];
    }

    if (self.progressPill) {
        [self.progressPill updateProgress:progress title:title subtitle:subtitle];
    } else {
        self.progressAlert.title = title;
        self.progressAlert.message = [NSString stringWithFormat:@"%@\n", subtitle];
        [self.progressView setProgress:progress animated:YES];
    }
}

- (void)adjustCurrentExpectedBytesIfNeeded:(unsigned long long)newExpectedBytes {
    unsigned long long oldExpectedBytes = self.currentExpectedBytes;
    if (newExpectedBytes <= oldExpectedBytes) return;

    self.currentExpectedBytes = newExpectedBytes;
    if (oldExpectedBytes > 0) {
        self.totalBytes += newExpectedBytes - oldExpectedBytes;
    } else if (!self.currentResolvedSizeAddedToTotal) {
        self.totalBytes += newExpectedBytes;
        self.currentResolvedSizeAddedToTotal = YES;
    }
}

- (void)startVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter {
    if (self.active) {
        YouModSendToast(LOC(@"ALREADY_DOWNLOADING"));
        return;
    }
    [self startDirectVideoDownloadWithVideoFormat:videoFormat audioFormat:audioFormat fileName:fileName videoID:videoID presenter:presenter];
}

- (void)startDirectVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter {
    NSURL *videoURL = [NSURL URLWithString:videoFormat.urlString];
    NSURL *audioURL = [NSURL URLWithString:audioFormat.urlString];
    if (!videoURL || !audioURL) {
        YouModSendError(LOC(@"NO_STREAM_URL"));
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = videoFormat.contentLength + audioFormat.contentLength;
    self.videoTempURL = YouModTemporaryFileURL(YouModFileExtensionForFormat(videoFormat));
    self.audioTempURL = YouModTemporaryFileURL(YouModFileExtensionForFormat(audioFormat));
    NSString *outputExtension = YouModMergedVideoOutputExtension(videoFormat, audioFormat);
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:videoURL toURL:self.videoTempURL expectedBytes:videoFormat.contentLength headers:nil completion:^(NSURL *videoFileURL, NSError *videoError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (videoError) {
            [self failWithError:videoError ?: [NSError errorWithDomain:@"YouMod" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Video download failed"}]];
            return;
        }

        self.completedBytes += MAX(videoFormat.contentLength, self.currentBytes);
        [self updateProgressTitle:LOC(@"DOWNLOADING_AUDIO") progress:(self.totalBytes ? (float)self.completedBytes / (float)self.totalBytes : 0.5f)];
        [self downloadURL:audioURL toURL:self.audioTempURL expectedBytes:audioFormat.contentLength headers:nil completion:^(NSURL *audioFileURL, NSError *audioError) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (audioError) {
                [self failWithError:audioError ?: [NSError errorWithDomain:@"YouMod" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Audio download failed"}]];
                return;
            }
            unsigned long long durationMs = videoFormat.durationMs ?: audioFormat.durationMs;
            [self mergeVideoURL:videoFileURL audioURL:audioFileURL fileName:fileName outputExtension:outputExtension durationMs:durationMs presenter:presenter];
        }];
    }];
}

- (void)startDirectSingleVideoDownloadWithFormat:(YouModMediaFormat *)format fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter {
    NSURL *videoURL = [NSURL URLWithString:format.urlString];
    if (!videoURL) {
        YouModSendError(LOC(@"NO_STREAM_URL"));
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = format.contentLength;
    NSString *extension = YouModFileExtensionForFormat(format);
    BOOL canFinalizeWithAVFoundation = format.durationMs > 0 && YouModPathExtensionIsPhotosVideo(extension);
    NSURL *finalURL = YouModUniqueFileURL(fileName, extension);
    NSURL *downloadURL = canFinalizeWithAVFoundation ? YouModTemporaryFileURL(extension) : finalURL;
    self.videoTempURL = canFinalizeWithAVFoundation ? downloadURL : nil;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:videoURL toURL:downloadURL expectedBytes:format.contentLength headers:nil completion:^(NSURL *fileURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || error) {
            [self failWithError:error ?: [NSError errorWithDomain:@"YouMod" code:8 userInfo:@{NSLocalizedDescriptionKey: @"Video download failed"}]];
            return;
        }
        if (canFinalizeWithAVFoundation) {
            [self trimSingleVideoURL:fileURL outputURL:finalURL durationMs:format.durationMs presenter:presenter];
            return;
        }
        [self completeWithFileURL:fileURL isVideo:YES presenter:presenter];
    }];
}

- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter {
    [self startAudioDownloadWithAudioFormat:audioFormat fileName:fileName videoID:videoID outputFormat:nil presenter:presenter];
}

- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID outputFormat:(YouModAudioOutputFormat *)outputFormat presenter:(UIViewController *)presenter {
    if (self.active) {
        YouModSendToast(LOC(@"ALREADY_DOWNLOADING"));
        return;
    }
    [self startDirectAudioDownloadWithAudioFormat:audioFormat fileName:fileName videoID:videoID outputFormat:outputFormat presenter:presenter];
}

- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID presenter:(UIViewController *)presenter {
    [self startDirectAudioDownloadWithAudioFormat:audioFormat fileName:fileName videoID:videoID outputFormat:nil presenter:presenter];
}

- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName videoID:(NSString *)videoID outputFormat:(YouModAudioOutputFormat *)outputFormat presenter:(UIViewController *)presenter {
    NSURL *audioURL = [NSURL URLWithString:audioFormat.urlString];
    if (!audioURL) {
        YouModSendError(LOC(@"NO_AUDIO_URL"));
        return;
    }
    outputFormat = outputFormat ?: YouModDefaultAudioOutputFormat();
    if (!outputFormat.supported) {
        YouModSendError([NSString stringWithFormat:@"%@ not supported", outputFormat.title ?: @"Format"]);
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = audioFormat.contentLength;
    
    NSURL *finalURL = YouModUniqueFileURL(fileName, @"m4a");
    NSURL *downloadURL = finalURL;
    self.audioTempURL = nil;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_AUDIO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:audioURL toURL:downloadURL expectedBytes:audioFormat.contentLength headers:nil completion:^(NSURL *fileURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (error) {
            [self failWithError:error ?: [NSError errorWithDomain:@"YouMod" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Audio download failed"}]];
            return;
        }
        [self completeWithFileURL:fileURL isVideo:NO presenter:presenter];
    }];
}

- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"MERGING_VID") progress:0.985f];
    NSURL *outputURL = YouModUniqueFileURL(fileName, outputExtension.length ? outputExtension : @"mp4");
    if (durationMs == 0) durationMs = YouModDurationMsForURL(videoURL);

    if (YouModVideoFileCanUseAVFoundation(outputURL)) {
        [self mergeVideoWithAVFoundationVideoURL:videoURL audioURL:audioURL outputURL:outputURL durationMs:durationMs presenter:presenter fallbackError:nil];
    } else {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:16 userInfo:@{NSLocalizedDescriptionKey: @"Cannot download audio from this stream"}]];
    }
}

- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError {
    [self updateProgressTitle:fallbackError ? LOC(@"MERGING_VID_FALLBACK") : LOC(@"MERGING_VID") progress:0.985f];
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    AVMutableComposition *composition = [AVMutableComposition composition];

    AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    AVAssetTrack *audioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!videoTrack || !audioTrack) {
        [self failWithError:fallbackError ?: [NSError errorWithDomain:@"YouMod" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]];
        return;
    }

    CMTime duration = YouModExportDuration(videoAsset, audioAsset, durationMs);
    if (!YouModCMTimeIsUsable(duration)) {
        [self failWithError:fallbackError ?: [NSError errorWithDomain:@"YouMod" code:9 userInfo:@{NSLocalizedDescriptionKey: @"Cannot determine duration"}]];
        return;
    }
    NSError *insertError = nil;
    AVMutableCompositionTrack *compositionVideo = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideo insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&insertError];
    compositionVideo.preferredTransform = videoTrack.preferredTransform;
    if (insertError) {
        [self failWithError:insertError];
        return;
    }

    AVMutableCompositionTrack *compositionAudio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:audioTrack atTime:kCMTimeZero error:&insertError];
    if (insertError) {
        [self failWithError:insertError];
        return;
    }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL = outputURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    self.exporter = exporter;

    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exporter.status == AVAssetExportSessionStatusCancelled) return;
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:YES presenter:presenter];
            } else {
                [self failWithError:exporter.error ?: [NSError errorWithDomain:@"YouMod" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]];
            }
        });
    }];
}

- (void)trimSingleVideoURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"FINA_VIDEO") progress:0.99f];
    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Cannot finalize video"}]];
        return;
    }

    CMTime duration = YouModExportDuration(asset, nil, durationMs);
    if (!YouModCMTimeIsUsable(duration)) {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:11 userInfo:@{NSLocalizedDescriptionKey: @"Cannot determine duration"}]];
        return;
    }

    AVMutableComposition *composition = [AVMutableComposition composition];
    NSError *insertError = nil;
    AVMutableCompositionTrack *compositionVideo = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideo insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&insertError];
    compositionVideo.preferredTransform = videoTrack.preferredTransform;
    if (insertError) {
        [self failWithError:insertError];
        return;
    }

    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (audioTrack) {
        CMTime audioDuration = YouModMinUsableDuration(duration, audioTrack.timeRange.duration);
        AVMutableCompositionTrack *compositionAudio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:&insertError];
        if (insertError) {
            [self failWithError:insertError];
            return;
        }
    }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL = outputURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    self.exporter = exporter;

    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exporter.status == AVAssetExportSessionStatusCancelled) return;
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:YES presenter:presenter];
            } else {
                [self failWithError:exporter.error ?: [NSError errorWithDomain:@"YouMod" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Finalize failed"}]];
            }
        });
    }];
}

- (void)completeWithFileURL:(NSURL *)fileURL isVideo:(BOOL)isVideo presenter:(UIViewController *)presenter {
    if (self.cancelled) return;
    self.active = NO;
    [self updateProgressTitle:LOC(@"DOWNLOAD_COMPLETED") progress:1.0f];
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self.progressAlert dismissViewControllerAnimated:YES completion:nil];
    self.progressAlert = nil;
    self.progressView = nil;

    BOOL canSaveToPhotos = isVideo && YouModVideoFileCanSaveToPhotos(fileURL);
    if (isVideo && IS_ENABLED(DownloadSaveToPhotos) && canSaveToPhotos) {
        [self cleanupTemporaryFiles];
        YouModSaveVideoToPhotos(fileURL, presenter, ^(BOOL success, NSError *error) {
            if (success) {
                YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
            } else {
                YouModSendError(error.localizedDescription ?: LOC(@"CANNOT_SAVE_TO_PHOTOS"));
                YouModShareFile(fileURL, presenter);
            }
        });
    } else {
        [self cleanupTemporaryFiles];
        YouModSendSuccess(isVideo ? LOC(@"DOWNLOAD_COMPLETED") : LOC(@"AUDIO_SAVED"));
        if (!isVideo || (isVideo && !canSaveToPhotos)) YouModShareFile(fileURL, presenter);
    }
}

- (void)failWithError:(NSError *)error {
    if (self.cancelled) return;
    self.active = NO;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self.progressAlert dismissViewControllerAnimated:YES completion:nil];
    self.progressAlert = nil;
    self.progressView = nil;
    [self cleanupTemporaryFiles];
    YouModSendError(error.localizedDescription ?: LOC(@"DOWNLOAD_FAILED"));
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.currentBytes = (unsigned long long)MAX(totalBytesWritten, 0);
    if (totalBytesExpectedToWrite > 0)
        [self adjustCurrentExpectedBytesIfNeeded:(unsigned long long)totalBytesExpectedToWrite];
    if (self.currentBytes > self.currentExpectedBytes)
        [self adjustCurrentExpectedBytesIfNeeded:self.currentBytes];
    [self updateDownloadProgressWithCurrentBytes:self.currentBytes expectedBytes:self.currentExpectedBytes];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    if (self.cancelled) return;
    self.finishedCurrentFile = YES;
    NSError *error = nil;
    [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    [NSFileManager.defaultManager moveItemAtURL:location toURL:self.destinationURL error:&error];
    if (self.fileCompletion) self.fileCompletion(error ? nil : self.destinationURL, error);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && !self.finishedCurrentFile && self.fileCompletion) {
        self.fileCompletion(nil, error);
    }
}

@end

static void YouModDownloadThumbnail(NSString *videoID, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURLForVideoID(videoID);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    YouModSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            YouModRequestPhotoAccess(^(BOOL granted) {
                if (!granted) {
                    YouModSendError(LOC(@"PHOTO_ACCESS_DENINED"));
                    return;
                }
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError *saveError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS")); else YouModSendError(saveError.localizedDescription ?: LOC(@"SAVE_FAILED"));
                    });
                }];
            });
        });
    }] resume];
}

static void YouModCopyVideoInfo(YTPlayerViewController *player, UIViewController *presenter) {
    NSString *videoID = YouModVideoIDForPlayer(player);
    NSString *title = YouModTitleForPlayer(player);
    NSString *url = videoID.length ? [NSString stringWithFormat:@"https://youtu.be/%@", videoID] : @"";
    UIPasteboard.generalPasteboard.string = url.length ? [NSString stringWithFormat:@"%@\n%@", title, url] : title;
    YouModSendSuccess(LOC(@"COPIED_VID_INFO"));
}

static void YouModShowVideoQualitySheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSArray <YouModMediaFormat *> *videoFormats = YouModFormatsForPlayer(player, YES);
    YouModMediaFormat *audioFormat = YouModBestAudioFormatForPlayer(player);
    NSString *title = YouModTitleForPlayer(player);
    NSString *videoID = YouModVideoIDForPlayer(player);

    if (videoFormats.count == 0 || !audioFormat) {
        YouModSendError(LOC(@"NO_VID_AUDIO_STREAM_FOUND"));
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    for (YouModMediaFormat *format in videoFormats) {
        NSString *label = format.qualityLabel;
        if ([label containsString:@"HDR"] || [label containsString:@"1440p"] || [label containsString:@"2160p"]) continue;
        NSString *rowTitle = label.length ? label : @"video";
        NSString *subtitle = YouModFormatSubtitle(format);
        [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModIconImage(658) handler:^{
            [[YouModDownloadCoordinator sharedCoordinator] startVideoDownloadWithVideoFormat:format audioFormat:audioFormat fileName:title videoID:videoID presenter:presenter];
        }]];
    }
    YouModPresentMenu(LOC(@"DOWNLOAD_VIDEO"), items, presenter, sender);
}

static void YouModShowAudioSourceSheet(YTPlayerViewController *player, YouModAudioOutputFormat *outputFormat, UIViewController *presenter, UIView *sender) {
    NSArray <YouModMediaFormat *> *audioFormats = YouModFormatsForPlayer(player, NO);
    NSString *title = YouModTitleForPlayer(player);
    NSString *videoID = YouModVideoIDForPlayer(player);

    if (audioFormats.count == 0) {
        YouModSendError(LOC(@"NO_AUDIO_STREAM_FOUND"));
        return;
    }

    YouModMediaFormat *bestFormat = audioFormats.firstObject;
    [[YouModDownloadCoordinator sharedCoordinator] startAudioDownloadWithAudioFormat:bestFormat fileName:title videoID:videoID outputFormat:outputFormat presenter:presenter];
}

static void YouModShowAudioSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    YouModAudioOutputFormat *defaultFormat = YouModDefaultAudioOutputFormat();
    YouModShowAudioSourceSheet(player, defaultFormat, presenter, sender);
}

static void YouModShowCaptionsSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSArray *tracks = YouModCaptionTracksForPlayer(player);
    if (tracks.count == 0) {
        YouModSendError(LOC(@"NO_CAPTIONS"));
        return;
    }
    
    NSMutableArray *items = [NSMutableArray array];
    for (id track in tracks) {
        NSString *baseURL = YouModStringFromSelector(track, @selector(baseURL));
        if (baseURL.length == 0) continue;
        
        NSString *languageCode = YouModStringFromSelector(track, @selector(languageCode));
        NSString *vssId = YouModStringFromSelector(track, @selector(vssId));
        NSString *nameStr = nil;
        id nameObj = YouModObjectFromSelector(track, @selector(name));
        nameStr = YouModStringFromSelector(nameObj, @selector(simpleText));
        if (!nameStr.length) {
            NSArray *runs = YouModObjectFromSelector(nameObj, @selector(runsArray));
            if (runs.count > 0) nameStr = YouModStringFromSelector(runs.firstObject, @selector(text));
        }
        if (!nameStr.length) nameStr = languageCode;
        if (!nameStr.length) nameStr = vssId;
        
        [items addObject:[YouModMenuItem itemWithTitle:nameStr subtitle:languageCode icon:YouModIconImage(637) handler:^{
            NSString *vttURL = [baseURL stringByAppendingString:@"&fmt=vtt"];
            NSURL *url = [NSURL URLWithString:vttURL];
            if (!url) {
                YouModSendError(LOC(@"NO_CAPTIONS_URL"));
                return;
            }
            YouModSendToast(LOC(@"DOWNLOADING_CAPTIONS"), presenter);
            [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error || data.length == 0) {
                        YouModSendError(LOC(@"CAPTIONS_FAILED"));
                        return;
                    }
                    NSString *videoID = YouModVideoIDForPlayer(player) ?: @"video";
                    NSString *filename = [NSString stringWithFormat:@"%@_%@.vtt", videoID, languageCode ?: @"captions"];
                    NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]];
                    [data writeToURL:tempURL atomically:YES];
                    YouModShareFile(tempURL, presenter);
                });
            }] resume];
        }]];
    }
    
    if (items.count == 0) {
        YouModSendError(LOC(@"NO_CAPTIONS_URL"));
        return;
    }
    
    YouModPresentMenu(LOC(@"DOWNLOAD_CAPTIONS"), items, presenter, sender);
}

static void YouModShowDownloadManager(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    if (!player) {
        YouModSendError(LOC(@"OPEN_VID_BEFORE"));
        return;
    }

    NSString *videoID = YouModVideoIDForPlayer(player);
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_VIDEO") subtitle:LOC(@"DOWNLOAD_VIDEO_DESC") icon:YouModIconImage(658) handler:^{
        YouModShowVideoQualitySheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_AUDIO") subtitle:LOC(@"DOWNLOAD_AUDIO_DESC") icon:YouModIconImage(21) handler:^{
        YouModShowAudioSheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_CAPTIONS") subtitle:LOC(@"DOWNLOAD_CAPTIONS_DESC") icon:YouModIconImage(637) handler:^{
        YouModShowCaptionsSheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_THUMBNAIL") subtitle:LOC(@"SAVE_THUMBNAIL_DESC") icon:YouModIconImage(367) handler:^{
        YouModDownloadThumbnail(videoID, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_VID_INFO") subtitle:LOC(@"COPY_VID_INFO_DESC") icon:YouModIconImage(250) handler:^{
        YouModCopyVideoInfo(player, presenter);
    }]];
    YouModPresentMenu(LOC(@"DOWNLOAD_MANAGER"), items, presenter, sender);
}

void YouModConfigureDownloadButton(_ASDisplayView *view) {
    if (![view.accessibilityIdentifier isEqualToString:@"id.ui.add_to.offline.button"]) return;
    if (!IS_ENABLED(DownloadManager) || IS_ENABLED(HideDownloadButton)) return;
    if (objc_getAssociatedObject(view, @selector(YouModDownloadButtonTapped:))) return;

    view.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModDownloadButtonTapped:)];
    tap.cancelsTouchesInView = YES;
    tap.delaysTouchesBegan = YES;
    tap.delaysTouchesEnded = YES;
    [view addGestureRecognizer:tap];
    objc_setAssociatedObject(view, @selector(YouModDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook _ASDisplayView

%new
- (void)YouModDownloadButtonTapped:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    UIViewController *presenter = YouModPresenterForSender(self, YouModCurrentPlayerViewController);
    YTPlayerViewController *player = YouModPlayerFromViewController(presenter);
    YouModShowDownloadManager(player, presenter, self);
}

%end

%hook YTPlayerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    YouModCurrentPlayerViewController = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (YouModCurrentPlayerViewController == self)
        YouModCurrentPlayerViewController = nil;
}

%end

NSString *YouModGlobalAuthHeader = nil;

%hook SSOAuthorization
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook SSOAuthorizationImpl
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook GNPSSOAuthorizationService
- (id)authToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end
