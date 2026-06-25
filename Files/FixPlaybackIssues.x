#import "Headers.h"
#import <YouTubeHeader/YTIClientInfo.h>
#import <YouTubeHeader/YTIInnerTubeContext.h>
#import <YouTubeHeader/YTIPlayerRequest.h>

static void ApplyAndroidTestSuiteSpoof(YTIClientInfo *context) {
    // The spoof is adapted from Morphe. https://github.com/MorpheApp/morphe-patches/blob/main/extensions/shared-youtube/library/src/main/java/app/morphe/extension/shared/spoof/ClientType.java
    if (context) {
        context.clientName = 14;
        context.deviceMake = @"Google";
        context.deviceModel = @"Pixel 10 Pro XL";
        context.osName = @"Android";
        context.osVersion = @"16";
        context.androidSdkVersion = 36;
        context.clientVersion = @"26.10.000";
    }
}

%hook YTIPlayerRequest 

- (void)setContext:(id)arg { 
    %orig;
    YTIInnerTubeContext *innertube = self.context;
    YTIClientInfo *context = innertube.client;
    ApplyAndroidTestSuiteSpoof(context);
}

%end

%hook YTIInnerTubeContext

- (void)setClient:(id)arg {
    %orig;
    YTIClientInfo *context = self.client;
    ApplyAndroidTestSuiteSpoof(context);
}

%end

/*

static BOOL isReloaded = NO;

%hook YTPlayerViewController
- (int)state {
    int value = %orig;
    if (![self.UIDelegate isKindOfClass:%c(YTWatchController)]) return value;
    if (value == 7) {
        if (!isReloaded) {
            isReloaded = YES;
            YTWatchController *watchController = (YTWatchController *)self.UIDelegate;
            dispatch_async(dispatch_get_main_queue(), ^{  
                [watchController reload];
            });
        }
    } else {
        isReloaded = NO;
    }
    return value;
}
%end

*/

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}