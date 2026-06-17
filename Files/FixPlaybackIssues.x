#import "Headers.h"

%hook YTPlayerViewController
- (int)state {
    int value = %orig;
    if (value == 7) {
        YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
        [watchController reload];
    }
    return %orig;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}