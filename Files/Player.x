#import "Headers.h"

extern void YouModDownloadSetCurrentPlayer(YTPlayerViewController *player);

static float playbackRate = 1.0;

static BOOL isAutoSelected = NO;

static void YouModAddEndTime(YTPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (!IS_ENABLED(ShowExtraTimeRemaining)) return;

    CGFloat rate = playbackRate != 0 ? playbackRate : 1.0;
    NSTimeInterval remainingSeconds = (lround(video.totalMediaTime) - lround(time.time)) / rate;

    int hours = (int)(remainingSeconds / 3600);
    int minutes = (int)(((int)remainingSeconds % 3600) / 60);
    int seconds = (int)((int)remainingSeconds % 60);

    NSString *remainingTimeText;
    if (hours > 0) {
        remainingTimeText = [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
    } else {
        remainingTimeText = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    }
    
    /*
    CGFloat rate = playbackRate != 0 ? playbackRate : 1.0;
    NSTimeInterval remainingTimetext = (lround(video.totalMediaTime) - lround(time.time)) / rate;
    NSString *remainingTime = remainingTimetext;

    // NSDate *estimatedEndTime = [NSDate dateWithTimeIntervalSinceNow:remainingTime];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"HH:mm"];
    // [dateFormatter setDateFormat:ytlBool(@"24hrFormat") ? @"HH:mm" : @"h:mm a"];
    */

    // NSString *formattedEndTime = [dateFormatter stringFromDate:estimatedEndTime];

    YTPlayerView *playerView = (YTPlayerView *)self.playerView;
    if (![playerView.overlayView isKindOfClass:%c(YTMainAppVideoPlayerOverlayView)]) return;

    YTMainAppVideoPlayerOverlayView *overlay = (YTMainAppVideoPlayerOverlayView*)playerView.overlayView;
    YTLabel *durationLabel = overlay.playerBar.durationLabel;

    if (![durationLabel.text containsString:remainingTimeText]) {
        durationLabel.text = [durationLabel.text stringByAppendingString:[NSString stringWithFormat:@" • %@", remainingTimeText]];
        [durationLabel sizeToFit];
    }
}

%hook YTMainAppControlsOverlayView
// Hide autoplay Switch
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { if (!IS_ENABLED(HideAutoPlayToggle)) %orig; }
// Hide captions Button
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { if (!IS_ENABLED(HideCaptionsButton)) %orig; }
// Hide video title in full screen
- (BOOL)titleViewHidden { return IS_ENABLED(HideFullvidTitle) ? YES : %orig; }
// Pause On Overlay
- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    YTSingleVideoController *sgvid = playerViewController.activeVideo;
    YTSingleVideoTime *sgtime = sgvid.localTime;
    if (visible) YouModAddEndTime(playerViewController, sgvid, sgtime);
    if (!IS_ENABLED(PauseOnOverlay)) return;
    visible ? [playerViewController pause] : [playerViewController play];
}
%end

%hook YTAutonavEndscreenController
- (void)showEndscreen { if (!IS_ENABLED(HideSuggestedVideo)) %orig; }
- (void)showEndscreenControlsInPlayerBar:(BOOL)arg { IS_ENABLED(HideSuggestedVideo) ? %orig(NO) : %orig; }
%end

%hook YTSettings
- (BOOL)isAutoplayEnabled { return IS_ENABLED(HideAutoPlayToggle) ? NO : %orig; }
%end

%hook YTSettingsImpl
- (BOOL)isAutoplayEnabled { return IS_ENABLED(HideAutoPlayToggle) ? NO : %orig; }
%end

/* idk what is this thing does
%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled {
    return NO;
}
%end

%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return IS_ENABLED(YTPremiumLogo) ? YES : NO; } // idk what is this does, the nav is already sticky... Or this thing only happens in iPhone?
- (void)setStickyNavHeaderEnabled:(BOOL)arg { IS_ENABLED(YTPremiumLogo) ? %orig(YES) : %orig(NO); }
%end
*/

// Remove Dark Background in Overlay
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 { IS_ENABLED(RemoveDarkOverlay) ? %orig(NO, arg2) : %orig; }
// Hide Watermarks
- (BOOL)isWatermarkEnabled { return IS_ENABLED(HideWaterMark) ? NO : %orig; }
- (void)setWatermarkEnabled:(BOOL)arg { IS_ENABLED(HideWaterMark) ? %orig(NO) : %orig; }
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(HideCastButtonPlayer)) self.playbackRouteButton.hidden = YES;    
}
- (BOOL)isFullscreenActionsVisible { return IS_ENABLED(HideFullAction) ? NO : %orig; }
%end

// No Endscreen Cards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)arg1 { IS_ENABLED(HideEndScreenCards) ? %orig(YES) : %orig; }
- (void)setHoverCardHidden:(BOOL)arg { IS_ENABLED(HideEndScreenCards) ? %orig(YES) : %orig; }
- (void)setHoverCardRenderer:(id)arg { if (!IS_ENABLED(HideEndScreenCards)) %orig; }
%end

%hook YTMainAppVideoPlayerOverlayViewController
// Disable Double Tap To Seek
- (BOOL)allowDoubleTapToSeekGestureRecognizer { return IS_ENABLED(DisablesDoubleTap) ? NO : %orig; }
// Disable long hold
- (BOOL)allowLongPressGestureRecognizerInView:(id)arg { return IS_ENABLED(DisablesLongHold) ? NO : %orig; }
// Copy timestamp on pause
- (void)didPressPause:(id)arg {
    %orig;
    if (!IS_ENABLED(CopyWithTimestampOnPause)) return;
    CGFloat mediaTimeIn = self.mediaTime;
    NSString *vidID = self.videoID;
    if (vidID.length)
        UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@&t=%lds", vidID, (long)mediaTimeIn];
}
%end

%hook YTColdConfig
- (BOOL)removeNextPaddleForAllVideos { return IS_ENABLED(HideNextAndPrevButtons) ? YES : %orig; }
- (BOOL)removePreviousPaddleForAllVideos { return IS_ENABLED(HideNextAndPrevButtons) ? YES : %orig; }
%end

// YTNoPaidPromo (https://github.com/PoomSmart/YTNoPaidPromo)
%group PaidPromoOverlay
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {}
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_paid_content"]) return;
    %orig;
}
%end

%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {}
%end
%end

// Remove Watermarks
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark { if (!IS_ENABLED(HideWaterMark)) %orig; }
%end

// Exit Fullscreen on Finish
%hook YTWatchFlowController
- (BOOL)shouldExitFullScreenOnFinish { return IS_ENABLED(AutoExitFullScreen) ? YES : %orig; }
%end

// Disable toggle time remaining - @bhackel
%hook YTInlinePlayerBarContainerView
- (void)setShouldDisplayTimeRemaining:(BOOL)arg1 { 
    if (IS_ENABLED(DisablesShowRemaining)) {
        %orig(NO);
        return;
    }
    IS_ENABLED(AlwaysShowRemaining) ? %orig(YES) : %orig;
}
%end

// Always use remaining time in the video player - @bhackel
%hook YTPlayerBarController
// When a new video is played, enable time remaining flag
- (void)setActiveSingleVideo:(id)arg1 {
    %orig;
    if (IS_ENABLED(AlwaysShowRemaining) && !IS_ENABLED(DisablesShowRemaining)) {
        // Get the player bar view
        YTInlinePlayerBarContainerView *playerBar = self.playerBar;
        if (playerBar) {
            // Enable the time remaining flag
            playerBar.shouldDisplayTimeRemaining = YES;
        }
    }
    YTSingleVideoController *sgvid = [self valueForKey:@"_currentSingleVideo"];
    YTPlayerView *playerview = [sgvid valueForKey:@"_playerView"];
    YTPlayerViewController *playerviewController = [playerview valueForKey:@"_playerViewDelegate"];
    YouModDownloadSetCurrentPlayer(playerviewController);
    if (IS_ENABLED(AutoFullScreen)) [playerviewController performSelector:@selector(YouModAutoFullscreen)];
    if (IS_ENABLED(ShortsToRegular)) [playerviewController performSelector:@selector(YouModShortsToRegular)];
    if (IS_ENABLED(DisablesCaptions)) [playerviewController performSelector:@selector(YouModTurnOffCaptions)];
    if (INTFORVAL(AutoSpeedIndex) != 0) [playerviewController performSelector:@selector(YouModSetAutoSpeed)];
}
%end

/*
%hook MLHAMPlayerItem

- (void)onSelectableVideoFormats:(NSArray <MLFormat *> *)formats {
    %orig;
    MLAVPlayer *avplayer = (MLAVPlayer *)self.playerItemDelegate;
    YTPlayerView *playerview = (YTPlayerView *)avplayer.renderingView;
    YTPlayerViewController *playerviewController = (YTPlayerViewController *)playerview.playerViewDelegate;
    if (INTFORVAL(WifiQualityIndex) != 0 || INTFORVAL(CellQualityIndex) != 0) [playerviewController performSelector:@selector(YouModAutoQuality)];
}

%end

%hook MLAVPlayer

- (void)streamSelectorHasSelectableVideoFormats:(NSArray <MLFormat *> *)formats {
    %orig;
    YTPlayerView *playerview = (YTPlayerView *)self.renderingView;
    YTPlayerViewController *playerviewController = (YTPlayerViewController *)playerview.playerViewDelegate;
    if (INTFORVAL(WifiQualityIndex) != 0 || INTFORVAL(CellQualityIndex) != 0) [playerviewController performSelector:@selector(YouModAutoQuality)];
}

%end

%hook MLAVAssetPlayer

// The changed value is not reliable but this method gets called whenever AirPlay session is started or stopped
- (void)playerExternalPlaybackActiveDidChange:(NSDictionary *)change {
    %orig;
    BOOL multipleScreens = [UIScreen screens].count > 1;
    if (isExternal != multipleScreens) {
        isExternal = multipleScreens;
        MLAVPlayer *player = (MLAVPlayer *)self.delegate;
        YTPlayerView *playerview = player.renderingView;
        YTPlayerViewController *playerviewController = playerview.playerViewDelegate;
        if (INTFORVAL(WifiQualityIndex) != 0 || INTFORVAL(CellQualityIndex) != 0) [playerviewController performSelector:@selector(YouModAutoQuality)];
    }
}

%end
*/

// Disable Fullscreen Actions
%hook YTFullscreenActionsView
- (CGSize)sizeThatFits:(CGSize)size { return IS_ENABLED(HideFullAction) ? CGSizeMake(1, 35) : %orig; }
%end

// Disable Ambiant mode (Hide the lights)
%hook YTCinematicContainerView
- (void)layoutSubviews { if (!IS_ENABLED(RemoveAmbiant)) %orig; }
- (void)loadWithModel:(id)arg { if (!IS_ENABLED(RemoveAmbiant)) %orig; }
- (id)initWithFrame:(CGRect)arg { return IS_ENABLED(RemoveAmbiant) ? nil : %orig; }
%end

// Disable Autoplay 
%hook YTPlaybackConfig
- (void)setStartPlayback:(BOOL)arg1 { IS_ENABLED(StopAutoplayVideo) ? %orig(NO) : %orig; }
%end

// Skip Content Warning (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L452-L454)
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { IS_ENABLED(HideContentWarning) ? [self confirmAlertDidPressConfirm] : %orig; }
%end

%hook YTPlayabilityResolutionUserActionUIControllerImpl
- (void)showConfirmAlert { IS_ENABLED(HideContentWarning) ? [self confirmAlertDidPressConfirm] : %orig; }
%end

// Always show seekbar
%hook YTInlinePlayerBarContainerView
- (void)setPlayerBarAlpha:(CGFloat)alpha { IS_ENABLED(AlwaysShowSeekbar) ? %orig(1.0) : %orig; }
%end

// Portrait Fullscreen
%hook YTWatchViewController
- (unsigned long long)allowedFullScreenOrientations { return IS_ENABLED(PortFull) ? UIInterfaceOrientationMaskAllButUpsideDown : %orig; }
%end

/* Disable Snap To Chapter (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L457-464) - GOT REMOVED
%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow { %orig; if (ytlBool(@"dontSnapToChapter")) self.enableSnapToChapter = NO; }
%end

%hook YTModularPlayerBarController
- (void)setEnableSnapToChapter:(BOOL)arg { %orig(NO); } // idk this works or not
%end
*/

// Replace previous/next buttons with back and forward
%hook YTColdConfig
- (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
- (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
%end

%group ForceMiniPlayer
%hook YTIMiniplayerRenderer
%new
- (BOOL)hasMinimizedEndpoint { return NO; }
%new
- (BOOL)hasPlaybackMode { return NO; }
%end
%end

// Extra speed - adapted from YouSpeed
%group Speed

#define itemCount 13

%hook YTMenuController

- (NSMutableArray <YTActionSheetAction *> *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)fromView entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    NSUInteger index = [renderers indexOfObjectPassingTest:^BOOL(YTIMenuItemSupportedRenderers *renderer, NSUInteger idx, BOOL *stop) {
        YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *extension = (YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *)[renderer.elementRenderer.compatibilityOptions messageForFieldNumber:396644439];
        BOOL isVideoSpeed = [extension.menuItemIdentifier isEqualToString:@"menu_item_playback_speed"];
        if (isVideoSpeed) *stop = YES;
        return isVideoSpeed;
    }];
    NSMutableArray <YTActionSheetAction *> *actions = %orig;
    if (index != NSNotFound) {
        YTActionSheetAction *action = actions[index];
        action.handler = ^{
            [firstResponder didPressVarispeed:fromView];
        };
        UIView *elementView = [action.button valueForKey:@"_elementView"];
        elementView.userInteractionEnabled = NO;
    }
    return actions;
}

%end

%hook YTVarispeedSwitchController

- (id)init {
    self = %orig;
    float speeds[] = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 5.0, 7.5, 10.0};
    id options[itemCount];
    Class YTVarispeedSwitchControllerOptionClass = %c(YTVarispeedSwitchControllerOption);
    for (int i = 0; i < itemCount; ++i) {
        NSString *title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
        options[i] = [[YTVarispeedSwitchControllerOptionClass alloc] initWithTitle:title rate:speeds[i]];
    }
    [self setValue:[NSArray arrayWithObjects:options count:itemCount] forKey:@"_options"];
    return self;
}

%end

%hook YTVarispeedSwitchControllerImpl

- (id)init {
    self = %orig;
    float speeds[] = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 5.0, 7.5, 10.0};
    id options[itemCount];
    Class YTVarispeedSwitchControllerOptionClass = %c(YTVarispeedSwitchControllerOption);
    for (int i = 0; i < itemCount; ++i) {
        NSString *title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
        options[i] = [[YTVarispeedSwitchControllerOptionClass alloc] initWithTitle:title rate:speeds[i]];
    }
    [self setValue:[NSArray arrayWithObjects:options count:itemCount] forKey:@"_options"];
    return self;
}

%end

%hook YTIPlayerHotConfig

%new(f@:)
- (float)maximumPlaybackRate {
    return 10.0;
}

%end

%hook YTIGranularVariableSpeedConfig

%new(d@:)
- (int)maximumPlaybackRate {
    return 10.0 * 100;
}

%end
%end

static CGFloat YouModRateBeforeHoldToSpeed = 1.0;

static NSArray *YouModHoldSpeedValues(void) {
    return @[@0.0, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
}

static CGFloat YouModSpeedForHoldIndex(NSInteger index) {
    NSArray *values = YouModHoldSpeedValues();
    return [values[index] floatValue];
}

static void YouModManageHoldToSpeed(UILongPressGestureRecognizer *gesture, YTMainAppVideoPlayerOverlayViewController *delegate) {
    NSInteger speedIndex = INTFORVAL(HoldToSpeedIndex);
    CGFloat speed = YouModSpeedForHoldIndex(speedIndex);

    if (gesture.state == UIGestureRecognizerStateBegan) {
        YouModRateBeforeHoldToSpeed = [delegate currentPlaybackRate];
        [delegate setPlaybackRate:speed];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        [delegate setPlaybackRate:YouModRateBeforeHoldToSpeed];
    }
}

%hook YTMainAppVideoPlayerOverlayView
- (void)setLongPressGestureRecognizer:(id)arg1 {
    if (INTFORVAL(HoldToSpeedIndex) != 0) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModHoldToSpeed:)];
        longPress.minimumPressDuration = 0.3;
        [self addGestureRecognizer:longPress];
    } else {
        %orig;
    }
}
%new
- (void)YouModHoldToSpeed:(UILongPressGestureRecognizer *)gesture {
    YouModManageHoldToSpeed(gesture, self.delegate);
}
%end

%hook YTPlayerViewController

- (BOOL)zoomToFill { return NO; }
- (void)setZoomToFill:(BOOL)arg { %orig(NO); }

- (id)activeVideo {
    id value = %orig;
    if (value) {
        if (!isAutoSelected) {
            YouModDownloadSetCurrentPlayer(self);
            if (IS_ENABLED(AutoFullScreen)) [self performSelector:@selector(YouModAutoFullscreen)];
            if (IS_ENABLED(ShortsToRegular)) [self performSelector:@selector(YouModShortsToRegular)];
            if (IS_ENABLED(DisablesCaptions)) [self performSelector:@selector(YouModTurnOffCaptions)];
            if (INTFORVAL(AutoSpeedIndex) != 0) [self performSelector:@selector(YouModSetAutoSpeed)];
            isAutoSelected = YES;
        }
    } else {
        isAutoSelected = NO;
    }
    return value;
}

%new
- (void)YouModTurnOffCaptions {
    if ([self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        [self setActiveCaptionTrack:nil source:0];
    }
}

%new
- (void)YouModAutoFullscreen {
    YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
    [watchController showFullScreen];
}

%new
- (void)YouModSetAutoSpeed {
    if ([self.activeVideoPlayerOverlay isKindOfClass:NSClassFromString(@"YTMainAppVideoPlayerOverlayViewController")]
        && [self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        YTMainAppVideoPlayerOverlayViewController *overlayVC = (YTMainAppVideoPlayerOverlayViewController *)self.activeVideoPlayerOverlay;

        NSArray *speedLabels = @[@0.01, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
        [overlayVC setPlaybackRate:[speedLabels[INTFORVAL(AutoSpeedIndex)] floatValue]];
    }
}

%new
- (void)YouModAutoQuality {
    if (![self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        return;
    }

    BOOL isWifi = [[%c(GCKNNetworkReachability) sharedInstance] currentStatus] == 1;
    NSInteger kQualityIndex = isWifi ? INTFORVAL(WifiQualityIndex) : INTFORVAL(CellQualityIndex);

    NSString *bestQualityLabel;
    int highestResolution = 0;
    for (MLFormat *format in self.activeVideo.selectableVideoFormats) {
        int reso = format.singleDimensionResolution;
        if (reso > highestResolution) {
            highestResolution = reso;
            bestQualityLabel = format.qualityLabel;
        }
    }

    NSArray *qualityLabels = @[@"Default", bestQualityLabel, @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60", @"1080p", @"720p60", @"720p", @"480p", @"360p", @"240p", @"144p"];
    NSString *qualityLabel = qualityLabels[kQualityIndex];

    if (![qualityLabel isEqualToString:bestQualityLabel]) {
        BOOL exactMatch = NO;
        NSString *closestQualityLabel = qualityLabel;

        for (MLFormat *format in self.activeVideo.selectableVideoFormats) {
            if ([format.qualityLabel isEqualToString:qualityLabel]) {
                exactMatch = YES;
                break;
            }
        }

        if (!exactMatch) {
            NSInteger bestQualityDifference = NSIntegerMax;

            for (MLFormat *format in self.activeVideo.selectableVideoFormats) {
                NSArray *formatСomponents = [format.qualityLabel componentsSeparatedByString:@"p"];
                NSArray *targetComponents = [qualityLabel componentsSeparatedByString:@"p"];
                if (formatСomponents.count == 2) {
                    NSInteger formatQuality = [formatСomponents.firstObject integerValue];
                    NSInteger targetQuality = [targetComponents.firstObject integerValue];
                    NSInteger difference = labs(formatQuality - targetQuality);
                    if (difference < bestQualityDifference) {
                        bestQualityDifference = difference;
                        closestQualityLabel = format.qualityLabel;
                    }
                }
            }

            qualityLabel = closestQualityLabel;
        }
    }

    MLQuickMenuVideoQualitySettingFormatConstraint *fc = [[%c(MLQuickMenuVideoQualitySettingFormatConstraint) alloc] init];
    if ([fc respondsToSelector:@selector(initWithVideoQualitySetting:formatSelectionReason:qualityLabel:resolutionCap:)]) {
        [self.activeVideo setVideoFormatConstraint:[fc initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel resolutionCap:0]];
    } else {
        [self.activeVideo setVideoFormatConstraint:[fc initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel]];
    }
}

- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

- (void)setPlaybackRate:(float)rate {
    playbackRate = rate;
    %orig;
}

%new
- (void)YouModShortsToRegular {
    if (self.contentVideoID != nil && [self.parentViewController isKindOfClass:NSClassFromString(@"YTReelPlayerViewController")]) {
        NSString *vidLink = [NSString stringWithFormat:@"vnd.youtube://%@", self.contentVideoID];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:vidLink]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:vidLink] options:@{} completionHandler:nil];
        }
    }
}
%end

/*
// Fix Playlist Mini-bar Height For Small Screens
%hook YTPlaylistMiniBarView
- (void)setFrame:(CGRect)frame {
    if (frame.size.height < 54.0) frame.size.height = 54.0; // what
    %orig(frame);
}
%end
*/

// YTClassicVideoQuality (https://github.com/PoomSmart/YTClassicVideoQuality)
%group OldVideoQuality
%hook YTIMediaQualitySettingsHotConfig
%new(B@:)
- (BOOL)enableQuickMenuVideoQualitySettings { return NO; }
%end

%hook YTVideoQualitySwitchOriginalController
%property (retain, nonatomic) YTVideoQualitySwitchRedesignedController *redesignedController;
- (void)setUserSelectableFormats:(NSArray <MLFormat *> *)formats {
    if (self.redesignedController == nil)
        self.redesignedController = [[%c(YTVideoQualitySwitchRedesignedController) alloc] initWithServiceRegistryScope:nil parentResponder:nil];
    [self.redesignedController setValue:[self valueForKey:@"_video"] forKey:@"_video"];
    NSArray <MLFormat *> *newFormats = [self.redesignedController respondsToSelector:@selector(addRestrictedFormats:)] ? [self.redesignedController addRestrictedFormats:formats] : formats;
    %orig(newFormats);
}
- (void)dealloc {
    self.redesignedController = nil;
    %orig;
}
%end

%hook YTMenuController
- (NSMutableArray <YTActionSheetAction *> *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)fromView entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    NSUInteger index = [renderers indexOfObjectPassingTest:^BOOL(YTIMenuItemSupportedRenderers *renderer, NSUInteger idx, BOOL *stop) {
        YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *extension = (YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *)[renderer.elementRenderer.compatibilityOptions messageForFieldNumber:396644439];
        BOOL isVideoQuality = [extension.menuItemIdentifier isEqualToString:@"menu_item_video_quality"];
        if (isVideoQuality) *stop = YES;
        return isVideoQuality;
    }];
    NSMutableArray <YTActionSheetAction *> *actions = %orig;
    if (index != NSNotFound) {
        YTActionSheetAction *action = actions[index];
        action.handler = ^{
            [firstResponder didPressVideoQuality:fromView];
        };
        UIView *elementView = [action.button valueForKey:@"_elementView"];
        elementView.userInteractionEnabled = NO;
    }
    return actions;
}
%end
%end

// Gestures - @bhackel (YTLitePlus)
%group Gestures
%hook YTWatchLayerViewController
// invoked when the player view controller is either created or destroyed
- (void)watchController:(YTWatchController *)watchController didSetPlayerViewController:(YTPlayerViewController *)playerViewController {
    if (playerViewController) {
        // check to see if the pan gesture is already created
        if (!playerViewController.YouModPanGesture) {
            playerViewController.YouModPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHandlePanGesture:)];
            playerViewController.YouModPanGesture.delegate = playerViewController;
            [playerViewController.playerView addGestureRecognizer:playerViewController.YouModPanGesture];
        }        
    }
    %orig;
}
%end

%hook YTPlayerViewController
%property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
%property (nonatomic, retain) UILabel *YouModGestureHUD;
%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture) {
        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint startLocation = [panGesture locationInView:self.view];
        CGFloat viewWidth = self.view.bounds.size.width;

        float areaPercent = 0.15;
        int areaSetting = INTFORVAL(GestureActivationArea);
        if (areaSetting == 0) areaPercent = 0.10;
        else if (areaSetting == 2) areaPercent = 0.20;
        else if (areaSetting == 3) areaPercent = 0.25;
        else if (areaSetting == 4) areaPercent = 0.30;
        else if (areaSetting == 5) areaPercent = 0.35;
        else if (areaSetting == 6) areaPercent = 0.40;
        else if (areaSetting == 7) areaPercent = 0.45;
        else if (areaSetting == 8) areaPercent = 0.50;

        int leftAction = [[NSUserDefaults standardUserDefaults] objectForKey:LeftSideGesture] ? INTFORVAL(LeftSideGesture) : 1;
        int rightAction = [[NSUserDefaults standardUserDefaults] objectForKey:RightSideGesture] ? INTFORVAL(RightSideGesture) : 2;

        // Ignore touches in the center area -> YouTube's default features (swipe down to dismiss, etc.) work normally
        if (startLocation.x > viewWidth * areaPercent && startLocation.x < viewWidth * (1.0 - areaPercent)) return NO;

        // Ignore touches in the area where 'None' is selected in settings
        if (startLocation.x <= viewWidth * areaPercent && leftAction == 0) return NO;
        if (startLocation.x >= viewWidth * (1.0 - areaPercent) && rightAction == 0) return NO;

        // Only works for vertical swipes -> Does not interfere with YouTube's horizontal seek bar
        CGPoint velocity = [panGesture velocityInView:self.view];
        if (fabs(velocity.x) > fabs(velocity.y)) return NO;

        return YES;
    }
    return YES;
}
%new
- (void)YouModHandlePanGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
    static float initialVolume;
    static float initialBrightness;
    static float initialSpeed;
    static int controlType = 0;
    static CGFloat deadzoneStartingTranslation;
    static CGFloat sensitivityFactor = 1.0;

    static MPVolumeView *volumeView;
    static UISlider *volumeViewSlider;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
        for (UIView *view in volumeView.subviews) {
            if ([view isKindOfClass:[UISlider class]]) {
                volumeViewSlider = (UISlider *)view;
                break;
            }
        }
    });

    if (IS_ENABLED(GestureHUD)) {
        if (!self.YouModGestureHUD) {
            self.YouModGestureHUD = [[UILabel alloc] initWithFrame:CGRectZero];
            self.YouModGestureHUD.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
            self.YouModGestureHUD.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            self.YouModGestureHUD.tintColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            self.YouModGestureHUD.textAlignment = NSTextAlignmentCenter;
            self.YouModGestureHUD.layer.masksToBounds = YES;
            self.YouModGestureHUD.alpha = 0.0;
            [self.view addSubview:self.YouModGestureHUD];
        }
    }

    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint startLocation = [panGestureRecognizer locationInView:self.view];
        CGFloat viewWidth = self.view.bounds.size.width;

        float areaPercent = 0.15;
        int areaSetting = INTFORVAL(GestureActivationArea);
        if (areaSetting == 0) areaPercent = 0.10;
        else if (areaSetting == 2) areaPercent = 0.20;
        else if (areaSetting == 3) areaPercent = 0.25;
        else if (areaSetting == 4) areaPercent = 0.30;
        else if (areaSetting == 5) areaPercent = 0.35;
        else if (areaSetting == 6) areaPercent = 0.40;
        else if (areaSetting == 7) areaPercent = 0.45;
        else if (areaSetting == 8) areaPercent = 0.50;

        int leftAction = [[NSUserDefaults standardUserDefaults] objectForKey:LeftSideGesture] ? INTFORVAL(LeftSideGesture) : 1;
        int rightAction = [[NSUserDefaults standardUserDefaults] objectForKey:RightSideGesture] ? INTFORVAL(RightSideGesture) : 2;

        if (startLocation.x <= viewWidth * areaPercent) {
            controlType = leftAction; 
        } else if (startLocation.x >= viewWidth * (1.0 - areaPercent)) {
            controlType = rightAction;
        } else {
            controlType = 0; // Center area
        }
        
        deadzoneStartingTranslation = [panGestureRecognizer translationInView:self.view].y;
        
        if (controlType == 1) {
            initialBrightness = [UIScreen mainScreen].brightness;
        } else if (controlType == 2) {
            initialVolume = [[AVAudioSession sharedInstance] outputVolume];
        } else if (controlType == 3) {
            initialSpeed = playbackRate;
        }

        if (IS_ENABLED(GestureHUD)) {
            int sizeSetting = [[NSUserDefaults standardUserDefaults] objectForKey:GestureHUDSize] ? (int)[[NSUserDefaults standardUserDefaults] integerForKey:GestureHUDSize] : 1;
            CGFloat fontSize = 14.0 + (sizeSetting * 2.0);
            CGFloat hudWidth = 74.0 + (sizeSetting * 10.0);
            CGFloat hudHeight = 30.0 + (sizeSetting * 4.0);
            
            self.YouModGestureHUD.frame = CGRectMake(0, 0, hudWidth, hudHeight);
            self.YouModGestureHUD.layer.cornerRadius = hudHeight / 2.0;
            self.YouModGestureHUD.font = [UIFont boldSystemFontOfSize:fontSize];

            int posSetting = [[NSUserDefaults standardUserDefaults] objectForKey:GestureHUDPosition] ? (int)[[NSUserDefaults standardUserDefaults] integerForKey:GestureHUDPosition] : 0;
            CGFloat viewHeight = self.view.bounds.size.height;
            CGFloat centerY = viewHeight / 6.0;
            if (posSetting == 1) centerY = viewHeight / 2.0;
            else if (posSetting == 2) centerY = viewHeight * 5.0 / 6.0;

            [self.view bringSubviewToFront:self.YouModGestureHUD];
            self.YouModGestureHUD.center = CGPointMake(viewWidth / 2, centerY);
        }
    }

    if (panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (controlType == 0) return;
        
        CGPoint translation = [panGestureRecognizer translationInView:self.view];
        CGFloat adjustedTranslation = translation.y - deadzoneStartingTranslation;
        
        // Vertical swipe: Value increases as it goes up (translation.y decreases)
        float delta = (-adjustedTranslation / self.view.bounds.size.height) * sensitivityFactor;
        
        NSString *symbolName = nil;
        NSString *percentString = nil;

        if (controlType == 1) {
            float newBrightness = fmaxf(fminf(initialBrightness + delta, 1.0), 0.0);
            [[UIScreen mainScreen] setBrightness:newBrightness];
            symbolName = @"sun.max.fill";
            percentString = [NSString stringWithFormat:@" %d%%", (int)(newBrightness * 100)];
        } else if (controlType == 2) {
            float newVolume = fmaxf(fminf(initialVolume + delta, 1.0), 0.0);
            volumeViewSlider.value = newVolume;
            symbolName = @"speaker.wave.2.fill";
            percentString = [NSString stringWithFormat:@" %d%%", (int)(newVolume * 100)];
        } else if (controlType == 3) {
            float speedSensitivity = 8.0; 
            float speedDelta = (-adjustedTranslation / self.view.bounds.size.height) * speedSensitivity;
            float rawSpeed = initialSpeed + speedDelta;
            float clampedSpeed = fmaxf(fminf(rawSpeed, 10.0), 0.25);
            // Quantize to 0.25x increments (e.g., 1.12 -> 1.0, 1.38 -> 1.25)
            float steppedSpeed = roundf(clampedSpeed * 4.0) / 4.0;

            // Only update if the stepped value has actually changed
            static float lastUpdatedSpeed = 0;
            if (steppedSpeed != lastUpdatedSpeed) {
                [self setPlaybackRate:steppedSpeed];
                lastUpdatedSpeed = steppedSpeed;
            }
            symbolName = @"speedometer";
            percentString = [NSString stringWithFormat:@" %.2fx", steppedSpeed];
        }

        if (IS_ENABLED(GestureHUD) && symbolName) {
            NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:self.YouModGestureHUD.font.pointSize - 1];
            UIImage *icon = [UIImage systemImageNamed:symbolName withConfiguration:config];
            attachment.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            CGFloat iconY = (self.YouModGestureHUD.font.capHeight - attachment.image.size.height) / 2.0;
            attachment.bounds = CGRectMake(0, iconY, attachment.image.size.width, attachment.image.size.height);
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
            NSAttributedString *textString = [[NSAttributedString alloc] initWithString:percentString attributes:@{NSFontAttributeName: self.YouModGestureHUD.font, NSForegroundColorAttributeName: self.YouModGestureHUD.textColor}];
            [attributedString appendAttributedString:textString];
            self.YouModGestureHUD.attributedText = attributedString;
        }
        if (IS_ENABLED(GestureHUD)) self.YouModGestureHUD.alpha = 1.0;
    } else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded || panGestureRecognizer.state == UIGestureRecognizerStateCancelled || panGestureRecognizer.state == UIGestureRecognizerStateFailed) {
        if (IS_ENABLED(GestureHUD)) {
            [UIView animateWithDuration:0.3 delay:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.YouModGestureHUD.alpha = 0.0;
            } completion:nil];
        }
    }
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // Require other gestures (like YouTube's related videos swipe) to fail when our gesture is active to prevent conflicts.
    if (gestureRecognizer == self.YouModPanGesture && [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture) {
        return NO; // Prevents simultaneous recognition with YouTube's default swipe when gestures overlap.
    }
    return YES;
}
%end
%end

%ctor {
    %init;
    if (IS_ENABLED(OldQualityPicker)) {
        %init(OldVideoQuality);
    }
    if (IS_ENABLED(ExtraSpeed) || IS_ENABLED(GestureControls) || INTFORVAL(HoldToSpeedIndex) >= 9 || INTFORVAL(AutoSpeedIndex) >= 9) {
        %init(Speed);
    }
    if (IS_ENABLED(HidePaidPromoOverlay)) {
        %init(PaidPromoOverlay);
    }
    if (IS_ENABLED(GestureControls)) {
        %init(Gestures);
    }
    if (IS_ENABLED(ForceMiniPlayer)) {
        %init(ForceMiniPlayer);
    }
}
