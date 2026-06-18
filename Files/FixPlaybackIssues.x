#import "Headers.h"

@interface YTSingleVideoController (YouMod)
- (void)play;
@end

static BOOL isReloaded = NO;

%hook YTSingleVideoController

- (int)playerPlaybackState {
    // 1. เรียกใช้งานคำสั่งดั้งเดิมของ YouTube เพียง "ครั้งเดียว" และเซฟค่าไว้
    int actualState = %orig;

    if (actualState == 6) {
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
    
    // 4. ส่งค่าที่เราเซฟไว้ตั้งแต่รอบแรกกลับไปให้ YouTube เอาไปประมวลผลต่อตามปกติ
    return actualState;
}

%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}
