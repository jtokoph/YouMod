#import "Headers.h"

#define TweakName @"YouMod"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakName]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

// Tab icons
%hook YTAppPivotBarItemStyle
- (UIImage *)pivotBarItemIconImageWithIconType:(int)type color:(UIColor *)color useNewIcons:(BOOL)isNew selected:(BOOL)isSelected {
    if (type == 1 || type == 2 || type == 3 || type == 4) {
        NSString *imageName;
        if (type == 1) imageName = isSelected ? @"icons/history_selected" : @"icons/history";
        else if (type == 2) imageName = isSelected ? @"icons/gaming_selected" : @"icons/gaming";
        else if (type == 3) imageName = isSelected ? @"icons/sports_selected" : @"icons/sports";
        else if (type == 4) imageName = isSelected ? @"icons/noti_selected" : @"icons/noti";
        YTAssetLoader *al = [[%c(YTAssetLoader) alloc] initWithBundle:YouModBundle()];
        return [al imageNamed:imageName];
    }
    return %orig;
}
%end

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSMutableIndexSet *indicesToRemove = [NSMutableIndexSet indexSet];
    // Loop through every item in the bar
    for (NSUInteger i = 0; i < items.count; i++) {
        YTIPivotBarSupportedRenderers *item = items[i];
        NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
        NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
        if ([pID isEqualToString:@"FEwhat_to_watch"] && IS_ENABLED(HideHomeTab)) {
             [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEshorts"] && IS_ENABLED(HideShortsTab)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID2 isEqualToString:@"FEuploads"] && IS_ENABLED(HideCreateButton)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEsubscriptions"] && IS_ENABLED(HideSubscriptTab)) {
            [indicesToRemove addIndex:i];
        }
    }
    // Remove them all at once so the layout doesn't break
    [items removeObjectsAtIndexes:indicesToRemove];
    // Add tabs - Will find some ways to re-arrange them
    NSUInteger historyIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForHistory]];
    }];
    NSUInteger gamingIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForGamingDestination]];
    }];
    NSUInteger sportsIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForSportsDestination]];
    }];
    NSUInteger notiIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForNotificationsInbox]];
    }];
    if (historyIndex == NSNotFound && IS_ENABLED(AddsHistoryTab)) {
        YTIPivotBarSupportedRenderers *historyTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForHistory] title:LOC(@"HISTORY_TAB") iconType:1];
        NSUInteger insertIndex = MIN((NSUInteger)1, items.count);
        [items insertObject:historyTab atIndex:insertIndex];
    }
    if (gamingIndex == NSNotFound && IS_ENABLED(AddsGamingTab)) {
        YTIPivotBarSupportedRenderers *gamingTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForGamingDestination] title:LOC(@"GAMING_TAB") iconType:2];
        NSUInteger insertIndex = MIN((NSUInteger)1, items.count);
        [items insertObject:gamingTab atIndex:insertIndex];
    }
    if (sportsIndex == NSNotFound && IS_ENABLED(AddsSportsTab)) {
        YTIPivotBarSupportedRenderers *sportsTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForSportsDestination] title:LOC(@"SPORTS_TAB") iconType:3];
        NSUInteger insertIndex = MIN((NSUInteger)1, items.count);
        [items insertObject:sportsTab atIndex:insertIndex];
    }
    if (notiIndex == NSNotFound && IS_ENABLED(AddsNotiTab)) {
        YTIPivotBarSupportedRenderers *notiTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForNotificationsInbox] title:LOC(@"NOTI_TAB") iconType:4];
        NSUInteger insertIndex = MIN((NSUInteger)1, items.count);
        [items insertObject:notiTab atIndex:insertIndex];
    }
    %orig(renderer);
}
%end

%hook YTBubbleHintView
- (id)initWithTargetView:(id)arg1 hintText:(id)arg2 detailsText:(id)arg3 acceptButton:(id)arg4 dismissButton:(id)arg5 maxWidth:(CGFloat)arg6 preferredPosition:(int)arg7 margin:(CGFloat)arg8 { return nil; }
- (void)setHintViewDelegate:(id)arg {}
%end

// Hide Tab Bar Indicators
%hook YTPivotBarIndicatorView
- (void)setFillColor:(id)arg1 { IS_ENABLED(HideTabIndi) ? %orig([UIColor clearColor]) : %orig; }
- (void)setBorderColor:(id)arg1  { IS_ENABLED(HideTabIndi) ? %orig([UIColor clearColor]) : %orig; }
%end

// Hide Tab Labels
%hook YTPivotBarItemView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    %orig;
    if (IS_ENABLED(HideTabLabels)) {
        [self.navigationButton setTitle:@"" forState:UIControlStateNormal];
        [self.navigationButton setSizeWithPaddingAndInsets:NO];
    }
}
%end

// Startup Tab
BOOL isTabSelected = NO;
%hook YTPivotBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isTabSelected) {
        NSArray *pivotIdentifiers = @[@"FEwhat_to_watch", @"FEshorts", @"FEsubscriptions", @"FElibrary"];
        [self selectItemWithPivotIdentifier:pivotIdentifiers[INTFORVAL(DefaultTab)]]; // Set int here
        isTabSelected = YES;
    }
}
- (BOOL)isFrostedPivotBarPermitted { return IS_ENABLED(HideTabLabels); }
%end
