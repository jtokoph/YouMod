#import "Headers.h"

@interface YTLocalPlaybackController : NSObject
- (int)state;
@end

@interface YTSingleVideoController ()
- (void)play;
@end

static BOOL isReloaded = NO;

%hook YTSingleVideoController

- (void)stateDidChangeFromState:(NSInteger)arg1 toState:(NSInteger)arg2 playerInitiated:(BOOL)arg3 lastSeekSource:(int)arg4 stoppageReason:(int)arg5 {
    %orig;
    YTLocalPlaybackController *pb = (YTLocalPlaybackController *)self.delegate;
    int actualState = pb.state;

    if (actualState == 7) {
        if (!isReloaded) {
            isReloaded = YES; // ล็อกสถานะทันทีเพื่อกันเหนียว
            // 2. ใช้ __weak ดักไว้ เผื่อผู้ใช้กดปิดหน้าวิดีโอหนีไปในเสี้ยววินาทีนั้น จะได้ไม่แครช
            __weak typeof(self) weakSelf = self;
            
            // 3. ปลอดภัยสูงสุด: โยนคำสั่งอัปเดต UI ไปรันบน Main Queue (Main Thread) อัตโนมัติ
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf) return;
                
                @try {
                    [weakSelf reloadPlayerWithContext:nil];
                } @catch (NSException *exception) {
                    NSLog(@"[YouMod] Failed to safely reload _UIDelegate: %@", exception.reason);
                }
            });
        }
    } else {
        if (isReloaded) {
            [self play];
        }
        isReloaded = NO;
    }
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}
