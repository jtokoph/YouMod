#import "Headers.h"

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

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}