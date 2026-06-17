#import "Headers.h"

%hook YTPlayerViewController
- (int)state {
    int value = %orig;
    if (value == 7) {
        YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
        CGFloat oldTime = [self currentVideoMediaTime];
        [watchController reload];
        [self seekToTime:oldTime];
    }
    return %orig;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}