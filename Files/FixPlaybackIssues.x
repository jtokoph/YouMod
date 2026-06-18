#import "Headers.h"

@interface YTLocalPlaybackController : NSObject
- (void)play;
- (void)singleVideoController:(YTSingleVideoController *)arg1 requiresReloadWithContext:(id)arg2;
@end

static BOOL isReloaded = NO;

%hook YTLocalPlaybackController

- (int)state {
    int actualState = %orig;

    if (actualState == 7) {
        if (!isReloaded) {
            isReloaded = YES; // ล็อกสถานะทันทีเพื่อกันเหนียว
            // 2. ใช้ __weak ดักไว้ เผื่อผู้ใช้กดปิดหน้าวิดีโอหนีไปในเสี้ยววินาทีนั้น จะได้ไม่แครช
            __weak typeof(self) weakSelf = self;
            
            // 3. ปลอดภัยสูงสุด: โยนคำสั่งอัปเดต UI ไปรันบน Main Queue (Main Thread) อัตโนมัติ
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf) return;
                
                @try {
                    [weakSelf singleVideoController:nil requiresReloadWithContext:nil];
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
    return actualState;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}
