#import "Headers.h"

@interface YTLocalPlaybackController : NSObject
- (void)seekToTime:(CGFloat)arg1 toleranceBefore:(CGFloat)arg2 toleranceAfter:(CGFloat)arg3;
- (void)heartbeatControllerWantsToReloadLiveStream:(id)arg1 endpoint:(id)arg2;
- (YTSingleVideoTime *)contentVideoCurrentTime;
@end

static BOOL isReloaded = NO;

%hook YTLocalPlaybackController

- (int)state {
    // 1. เรียกใช้งานคำสั่งดั้งเดิมของ YouTube เพียง "ครั้งเดียว" และเซฟค่าไว้
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
                    // ดึงค่าอย่างระมัดระวัง
                    YTSingleVideoTime *watchController = weakSelf.contentVideoCurrentTime;
                    
                    // เช็กให้ชัวร์ว่า Object มีตัวตนอยู่จริงและมีเมธอด reload ให้เรียกใช้งาน
                    if (watchController && [watchController respondsToSelector:@selector(time)]) {
                        CGFloat aka = watchController.time;
                        [weakSelf heartbeatControllerWantsToReloadLiveStream:nil endpoint:nil];
                        [weakSelf seekToTime:aka toleranceBefore:nil toleranceAfter:nil];
                    }
                } @catch (NSException *exception) {
                    NSLog(@"[YouMod] Failed to safely reload _UIDelegate: %@", exception.reason);
                }
            });
        }
    } else {
        // ถ้าระบบกลับมาทำงานสถานะปกติ (ไม่ใช่ 7) ค่อยเปิดล็อกให้ทำงานใหม่ได้
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
