#import "Headers.h"

@interface YTLocalPlaybackController : NSObject
- (void)heartbeatControllerWantsToReloadLiveStream:(id)arg1 endpoint:(id)arg2;
@end

static BOOL isReloaded = NO;

%hook YTPlayerViewController

- (int)state {
    int actualState = %orig;

    if (actualState == 7) {
        if (!isReloaded) {
            YTLocalPlaybackController *pb = [self valueForKey:@"_playbackController"];
            isReloaded = YES; // ล็อกสถานะทันทีเพื่อกันเหนียว
            // 2. ใช้ __weak ดักไว้ เผื่อผู้ใช้กดปิดหน้าวิดีโอหนีไปในเสี้ยววินาทีนั้น จะได้ไม่แครช
            
            // 3. ปลอดภัยสูงสุด: โยนคำสั่งอัปเดต UI ไปรันบน Main Queue (Main Thread) อัตโนมัติ
            dispatch_async(dispatch_get_main_queue(), ^{  
                @try {
                    [pb heartbeatControllerWantsToReloadLiveStream:nil endpoint:nil];
                } @catch (NSException *exception) {
                    NSLog(@"[YouMod] Failed to safely reload _UIDelegate: %@", exception.reason);
                }
            });
        }
    } else {
        isReloaded = NO;
    }
    return actualState;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}
