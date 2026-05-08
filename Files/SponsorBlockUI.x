#import "Headers.h"
#import <objc/message.h>

#pragma mark - SBSkipNotificationView Implementation

@implementation SBSkipNotificationView

+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration {
    if (!parentView) return nil;

    for (UIView *sub in [parentView.subviews copy]) {
        if ([sub isKindOfClass:[SBSkipNotificationView class]]) {
            [(SBSkipNotificationView *)sub dismiss];
        }
    }

    SBSkipNotificationView *view = [[SBSkipNotificationView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.clipsToBounds = YES;
    view.layer.cornerRadius = 22.0;
    view.onAction = action;
    view.totalDuration = duration;
    view.remainingDuration = duration;
    view.isPaused = NO;

    // Base layer (revealed as progress depletes)
    view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];

    // Progress overlay (shrinks from right to left)
    UIView *progressOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    progressOverlay.translatesAutoresizingMaskIntoConstraints = YES;
    progressOverlay.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    progressOverlay.userInteractionEnabled = NO;
    progressOverlay.layer.anchorPoint = CGPointMake(0, 0.5);
    progressOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.progressOverlay = progressOverlay;
    [view addSubview:progressOverlay];

    // Message label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.numberOfLines = 2;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    view.messageLabel = label;
    [view addSubview:label];

    // Icon button (right side)
    BOOL showButton = (buttonTitle != nil || action != nil);
    UIButton *button = nil;

    if (showButton) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;

        NSString *iconName = @"forward.end.fill";
        if (buttonTitle && ([buttonTitle.lowercaseString containsString:@"unskip"] || [buttonTitle.lowercaseString containsString:@"back"])) {
            iconName = @"backward.fill";
        }

        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:iconName withConfiguration:config];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        button.layer.cornerRadius = 16.0;
        button.clipsToBounds = YES;
        [button addTarget:view action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        view.actionButton = button;
        [view addSubview:button];
    }

    [parentView addSubview:view];

    // Layout: centered horizontally, anchored above tab bar via safe area
    NSLayoutConstraint *maxWidth = [view.widthAnchor constraintLessThanOrEqualToAnchor:parentView.widthAnchor multiplier:0.85];
    [NSLayoutConstraint activateConstraints:@[
        [view.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
        [view.bottomAnchor constraintEqualToAnchor:parentView.safeAreaLayoutGuide.bottomAnchor constant:-60.0],
        [view.heightAnchor constraintEqualToConstant:44.0],
        maxWidth
    ]];

    // Internal layout
    if (showButton) {
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
            [label.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [label.trailingAnchor constraintEqualToAnchor:button.leadingAnchor constant:-10.0],

            [button.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8.0],
            [button.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [button.widthAnchor constraintEqualToConstant:32.0],
            [button.heightAnchor constraintEqualToConstant:32.0]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
            [label.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [label.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-40.0],
        ]];
    }

    // Pan gesture for interactive dismissal
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:view action:@selector(handlePan:)];
    [view addGestureRecognizer:pan];

    // Slide up from below
    view.transform = CGAffineTransformMakeTranslation(0, 60);
    view.alpha = 0.0;
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.alpha = 1.0;
        view.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished && duration > 0) {
            [view startProgressAnimation];
        }
    }];

    return view;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.progressOverlay.layer.animationKeys.count == 0 || self.isPaused) {
        self.progressOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    }
}

- (void)startProgressAnimation {
    if (self.remainingDuration <= 0) return;

    self.progressOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);

    [UIView animateWithDuration:self.remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressOverlay.transform = CGAffineTransformMakeScale(0.001, 1.0);
        self.progressOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (finished && !self.isPaused && self.superview) {
            [self dismiss];
        }
    }];
}

- (void)pauseProgress {
    if (self.isPaused) return;
    self.isPaused = YES;

    CALayer *presentationLayer = self.progressOverlay.layer.presentationLayer;
    CGFloat currentScaleX = 1.0;
    if (presentationLayer) {
        CATransform3D t = presentationLayer.transform;
        currentScaleX = t.m11;
    }

    [self.progressOverlay.layer removeAllAnimations];
    currentScaleX = MAX(0.001, MIN(currentScaleX, 1.0));
    self.progressOverlay.transform = CGAffineTransformMakeScale(currentScaleX, 1.0);
    self.progressOverlay.alpha = currentScaleX;
    self.remainingDuration = self.totalDuration * currentScaleX;
}

- (void)resumeProgress {
    if (!self.isPaused) return;
    self.isPaused = NO;

    if (self.remainingDuration <= 0) {
        [self dismiss];
        return;
    }

    [UIView animateWithDuration:self.remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressOverlay.transform = CGAffineTransformMakeScale(0.001, 1.0);
        self.progressOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (finished && !self.isPaused && self.superview) {
            [self dismiss];
        }
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.alpha < 1.0) {
        gesture.enabled = NO;
        gesture.enabled = YES;
        return;
    }

    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint velocity = [gesture velocityInView:self.superview];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            [self pauseProgress];
            break;

        case UIGestureRecognizerStateChanged:
            self.transform = CGAffineTransformMakeTranslation(0, translation.y);
            break;

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat distanceThreshold = 30.0;
            CGFloat velocityThreshold = 500.0;
            BOOL shouldDismiss = (fabs(translation.y) > distanceThreshold) || (fabs(velocity.y) > velocityThreshold);

            if (shouldDismiss) {
                CGFloat direction = (translation.y < 0) ? -1.0 : 1.0;
                [self dismissInDirection:direction velocity:fabs(velocity.y)];
            } else {
                // Snap back
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished) {
                    [self resumeProgress];
                }];
            }
            break;
        }
        default:
            break;
    }
}

- (void)dismissInDirection:(CGFloat)direction velocity:(CGFloat)velocity {
    CGFloat offscreenY = direction < 0 ? -(self.frame.size.height + 80) : (self.frame.size.height + 80);
    CGFloat animDuration = velocity > 500 ? 0.2 : 0.35;

    [UIView animateWithDuration:animDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, offscreenY);
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)actionButtonTapped {
    if (self.onAction) {
        self.onAction();
    }
    [self dismiss];
}

- (void)dismiss {
    [self.progressOverlay.layer removeAllAnimations];
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, 60);
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

+ (instancetype)showSuccessInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration {
    SBSkipNotificationView *view = [self showInView:parentView message:message buttonTitle:nil action:nil duration:duration];
    if (view) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config]];
        iconView.tintColor = [UIColor systemGreenColor];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [view addSubview:iconView];
        [NSLayoutConstraint activateConstraints:@[
            [iconView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12.0],
            [iconView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        ]];
    }
    return view;
}

+ (instancetype)showErrorInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration {
    SBSkipNotificationView *view = [self showInView:parentView message:message buttonTitle:nil action:nil duration:duration];
    if (view) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:config]];
        iconView.tintColor = [UIColor systemRedColor];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [view addSubview:iconView];
        [NSLayoutConstraint activateConstraints:@[
            [iconView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12.0],
            [iconView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        ]];
    }
    return view;
}

@end

#pragma mark - YTSegmentableInlinePlayerBarView Hook (Seek Bar Markers)

%hook YTSegmentableInlinePlayerBarView
%property (nonatomic, strong) NSArray *sbMarkerViews;

- (void)layoutSubviews {
    %orig;
    if (self.sbMarkerViews.count > 0) {
        // Call %new method via objc_msgSend to avoid compiler warning
        ((void (*)(id, SEL))objc_msgSend)(self, @selector(sbRepositionMarkers));
    }
}

%new
- (void)sbRenderSegments:(NSArray<SBSegment *> *)segments {
    [self sbClearSegments];

    CGFloat totalTime = 0;
    @try {
        totalTime = [[self valueForKey:@"totalTime"] floatValue];
    } @catch (NSException *e) { return; }
    if (totalTime <= 0 || segments.count == 0) return;

    CGFloat barWidth = self.bounds.size.width;
    CGFloat barHeight = self.bounds.size.height;
    if (barWidth <= 0) return;

    NSMutableArray *markers = [NSMutableArray array];

    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;

        CGFloat startFrac = segment.startTime / totalTime;
        CGFloat endFrac = segment.endTime / totalTime;
        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;
        if (w < 2.0) w = 2.0;

        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(x, barHeight - 4.0, w, 4.0)];
        marker.backgroundColor = [segment segmentColor];
        marker.userInteractionEnabled = NO;
        marker.layer.name = [NSString stringWithFormat:@"%f|%f", segment.startTime, segment.endTime];

        [self addSubview:marker];
        [markers addObject:marker];
    }

    self.sbMarkerViews = [markers copy];
}

%new
- (void)sbRepositionMarkers {
    CGFloat totalTime = 0;
    @try {
        totalTime = [[self valueForKey:@"totalTime"] floatValue];
    } @catch (NSException *e) { return; }
    if (totalTime <= 0) return;

    CGFloat barWidth = self.bounds.size.width;
    CGFloat barHeight = self.bounds.size.height;
    if (barWidth <= 0) return;

    for (UIView *marker in self.sbMarkerViews) {
        NSString *name = marker.layer.name;
        NSArray *parts = [name componentsSeparatedByString:@"|"];
        if (parts.count < 2) continue;

        CGFloat startTime = [parts[0] floatValue];
        CGFloat endTime = [parts[1] floatValue];
        CGFloat startFrac = startTime / totalTime;
        CGFloat endFrac = endTime / totalTime;
        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;
        if (w < 2.0) w = 2.0;

        marker.frame = CGRectMake(x, barHeight - 4.0, w, 4.0);
    }
}

%new
- (void)sbClearSegments {
    for (UIView *marker in self.sbMarkerViews) {
        [marker removeFromSuperview];
    }
    self.sbMarkerViews = nil;
}

%end

#pragma mark - YTInlinePlayerBarContainerView Hook (Marker Repositioning)

%hook YTInlinePlayerBarContainerView

- (void)layoutSubviews {
    %orig;

    // Find the player bar view and reposition markers
    UIView *playerBar = nil;
    if ([self respondsToSelector:@selector(modularPlayerBar)]) {
        id modular = self.modularPlayerBar;
        if ([modular respondsToSelector:@selector(view)]) {
            playerBar = [modular view];
        }
    }
    if (!playerBar && [self respondsToSelector:@selector(segmentablePlayerBar)]) {
        playerBar = (UIView *)self.segmentablePlayerBar;
    }
    if (!playerBar) return;

    CGFloat barWidth = playerBar.bounds.size.width;
    if (barWidth <= 0) return;

    // Find reference view for Y
    UIView *referenceView = nil;
    for (UIView *sub in playerBar.subviews) {
        if ([sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)] ||
            [sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)]) {
            referenceView = sub;
            break;
        }
    }

    CGFloat markerY = referenceView ? referenceView.frame.origin.y : (playerBar.bounds.size.height - 3.0);
    CGFloat markerHeight = referenceView ? referenceView.frame.size.height : 3.0;
    if (markerHeight < 2.0) markerHeight = 3.0;

    for (UIView *sub in playerBar.subviews) {
        if (sub.tag != 9900) continue;
        NSArray *data = objc_getAssociatedObject(sub, @selector(sbSegmentData));
        if (!data || data.count < 3) continue;

        CGFloat startFrac = [data[0] floatValue];
        CGFloat endFrac = [data[1] floatValue];
        BOOL isPoi = [data[2] boolValue];

        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;
        if (isPoi) { w = 3.0; x = MAX(0, x - 1.5); }
        else if (w < 2.0) w = 2.0;

        sub.frame = CGRectMake(x, markerY, w, markerHeight);
    }
}

%end

// YTModularPlayerBarView hook removed — class may not exist in YT 21.17.3
// Seek bar markers will use YTInlinePlayerBarContainerView directly instead

#pragma mark - YTPlayerViewController Hook (Notification Observer)

%group SBObserver
%hook YTPlayerViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSegmentsDidLoad" object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sbSegmentsDidLoad:)
                                                 name:@"SBSegmentsDidLoad"
                                               object:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSegmentsDidLoad" object:self];
    %orig;
}


%new
- (void)sbSegmentsDidLoad:(NSNotification *)notification {
    @try {
        NSArray<SBSegment *> *segments = notification.userInfo[@"segments"];

        id overlay = [self activeVideoPlayerOverlay];
        if (!overlay) return;

        YTPlayerBarController *barController = nil;
        if ([overlay respondsToSelector:@selector(playerBarController)]) {
            barController = [overlay playerBarController];
        }
        if (!barController) return;

        YTInlinePlayerBarContainerView *containerView = barController.playerBar;
        if (!containerView) return;

        // Find the actual player bar view (try modularPlayerBar first, then segmentablePlayerBar)
        UIView *playerBar = nil;
        if ([containerView respondsToSelector:@selector(modularPlayerBar)]) {
            id modular = containerView.modularPlayerBar;
            if ([modular respondsToSelector:@selector(view)]) {
                playerBar = [modular view];
            }
        }
        if (!playerBar && [containerView respondsToSelector:@selector(segmentablePlayerBar)]) {
            playerBar = (UIView *)containerView.segmentablePlayerBar;
        }
        if (!playerBar) playerBar = containerView; // Fallback

        // Remove old markers (tag 9900)
        for (UIView *sub in [playerBar.subviews copy]) {
            if (sub.tag == 9900) [sub removeFromSuperview];
        }

        if (!segments || segments.count == 0) return;

        CGFloat totalTime = [self currentVideoTotalMediaTime];
        if (totalTime <= 0) return;

        CGFloat barWidth = playerBar.bounds.size.width;
        if (barWidth <= 0) return;

        // Find reference track view for Y position and height
        UIView *referenceView = nil;
        UIView *scrubberView = nil;
        for (UIView *sub in playerBar.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                referenceView = sub;
            } else if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)]) {
                if (!referenceView) referenceView = sub;
            } else if ([sub isKindOfClass:%c(YTPlayerBarScrubberDotDecorationView)]) {
                scrubberView = sub;
            }
        }

        // Fallback Y/height if reference view not found
        CGFloat markerY = referenceView ? referenceView.frame.origin.y : (playerBar.bounds.size.height - 3.0);
        CGFloat markerHeight = referenceView ? referenceView.frame.size.height : 3.0;
        if (markerHeight < 2.0) markerHeight = 3.0;

        for (SBSegment *segment in segments) {
            SBSegmentAction action = [segment configuredAction];
            if (action == SBSegmentActionDisable) continue;

            CGFloat startFrac = segment.startTime / totalTime;
            CGFloat endFrac = segment.endTime / totalTime;
            CGFloat x = startFrac * barWidth;
            CGFloat w = (endFrac - startFrac) * barWidth;

            // poi_highlight is a point, not a range — give it fixed width
            BOOL isPoi = [segment.category isEqualToString:@"poi_highlight"];
            if (isPoi) {
                w = 3.0;
                x = MAX(0, x - 1.5);
            } else {
                if (w < 2.0) w = 2.0;
            }

            UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(x, markerY, w, markerHeight)];
            marker.backgroundColor = [segment segmentColor];
            marker.userInteractionEnabled = NO;
            marker.tag = 9900;
            objc_setAssociatedObject(marker, @selector(sbSegmentData), @[@(startFrac), @(endFrac), @(isPoi)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (referenceView) {
                [playerBar insertSubview:marker aboveSubview:referenceView];
            } else {
                [playerBar addSubview:marker];
            }
        }

        // Keep scrubber dot on top
        if (scrubberView) {
            [playerBar bringSubviewToFront:scrubberView.superview ?: scrubberView];
        }
    } @catch (NSException *e) {}
}

%end
%end

#pragma mark - YTMainAppControlsOverlayView Hook (Toggle Button)

%hook YTMainAppControlsOverlayView

- (void)layoutSubviews {
    %orig;

    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBShowButton)) {
        UIView *existing = [self viewWithTag:9901];
        if (existing) [existing removeFromSuperview];
        return;
    }

    UIButton *btn = (UIButton *)[self viewWithTag:9901];
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 9901;
        btn.frame = CGRectMake(0, 0, 40, 40);

        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:@"shield.fill" withConfiguration:config];
        [btn setImage:icon forState:UIControlStateNormal];
        btn.tintColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0];

        [btn addTarget:self action:@selector(sbButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
    }

    // Position: top-right
    CGFloat rightPad = 12.0;
    CGFloat topPad = 52.0;
    btn.frame = CGRectMake(self.bounds.size.width - 40 - rightPad, topPad, 40, 40);
}

- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    UIButton *btn = (UIButton *)[self viewWithTag:9901];
    if (btn) btn.hidden = !visible;
}

%new
- (void)sbButtonTapped:(UIButton *)sender {
    YTPlayerViewController *pvc = nil;
    if ([self respondsToSelector:@selector(playerViewController)]) {
        pvc = [self performSelector:@selector(playerViewController)];
    }
    if (!pvc) {
        // Try to find player VC via responder chain
        UIResponder *responder = self;
        while (responder) {
            if ([responder isKindOfClass:%c(YTPlayerViewController)]) {
                pvc = (YTPlayerViewController *)responder;
                break;
            }
            responder = [responder nextResponder];
        }
    }
    if (!pvc) {
        NSLog(@"[YouMod SponsorBlock] Unable to find YTPlayerViewController from button tap");
        return;
    }

    BOOL newState = !pvc.sbEnabledForVideo;
    pvc.sbEnabledForVideo = newState;

    sender.tintColor = newState ? [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0] : [UIColor grayColor];

    if (!newState) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:pvc
                                                          userInfo:@{@"segments": @[]}];
    } else {
        NSArray *segments = pvc.sbSegments;
        if (segments.count > 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                                object:pvc
                                                              userInfo:@{@"segments": segments}];
        }
    }
}

%end

#pragma mark - Constructor

%ctor {
    %init;
    %init(SBObserver);
}
