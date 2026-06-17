#import "Headers.h"

static BOOL isReloaded = NO;

%hook YTPlayerViewController
- (int)state {
    int value = %orig;
    if (value == 7) {
        if (!isReloaded) {
            YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
            [watchController reload];
            isReloaded = YES;
        }
    } else {
        isReloaded = NO;
    }
    return %orig;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}