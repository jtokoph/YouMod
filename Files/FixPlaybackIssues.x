#import "Headers.h"

%hook YTPlayerViewController
- (int)state {
    int value = %orig;
    if (value == 7) {
        __weak typeof(self) weakSelf = self;
        YTWatchController *watchController = [weakSelf valueForKey:@"_UIDelegate"];
        [watchController reload];
    }
    return %orig;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}