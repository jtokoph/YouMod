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

static NSString *ymPivotIDForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"home"]) return @"FEwhat_to_watch";
    if ([tabID isEqualToString:@"shorts"]) return @"FEshorts";
    if ([tabID isEqualToString:@"create"]) return @"FEuploads";
    if ([tabID isEqualToString:@"subscriptions"]) return @"FEsubscriptions";
    if ([tabID isEqualToString:@"library"]) return @"FElibrary";
    if ([tabID isEqualToString:@"history"]) return [%c(YTIBrowseRequest) browseIDForHistory];
    if ([tabID isEqualToString:@"gaming"]) return [%c(YTIBrowseRequest) browseIDForGamingDestination];
    if ([tabID isEqualToString:@"sports"]) return [%c(YTIBrowseRequest) browseIDForSportsDestination];
    if ([tabID isEqualToString:@"notifications"]) return [%c(YTIBrowseRequest) browseIDForNotificationsInbox];
    return nil;
}

static NSInteger ymIconTypeForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return 1;
    if ([tabID isEqualToString:@"gaming"]) return 2;
    if ([tabID isEqualToString:@"sports"]) return 3;
    if ([tabID isEqualToString:@"notifications"]) return 4;
    return 0;
}

static NSString *ymTitleForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return LOC(@"HISTORY_TAB");
    if ([tabID isEqualToString:@"gaming"]) return LOC(@"GAMING_TAB");
    if ([tabID isEqualToString:@"sports"]) return LOC(@"SPORTS_TAB");
    if ([tabID isEqualToString:@"notifications"]) return LOC(@"NOTI_TAB");
    return nil;
}

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:@"YouModTabOrder"];

    if (savedOrder.count > 0) {
        NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

        // Build lookup: pivotIdentifier -> renderer item
        NSMutableDictionary<NSString *, YTIPivotBarSupportedRenderers *> *lookup = [NSMutableDictionary dictionary];
        for (YTIPivotBarSupportedRenderers *item in items) {
            NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
            NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
            if (pID) lookup[pID] = item;
            if (pID2) lookup[pID2] = item;
        }

        // Build ordered array from saved data
        NSMutableArray *ordered = [NSMutableArray array];
        for (NSDictionary *entry in savedOrder) {
            NSString *tabID = entry[@"id"];
            BOOL enabled = [entry[@"enabled"] boolValue];
            if (!enabled) continue;

            NSString *pivotID = ymPivotIDForTabID(tabID);
            if (!pivotID) continue;

            YTIPivotBarSupportedRenderers *existing = lookup[pivotID];
            if (existing) {
                [ordered addObject:existing];
            } else {
                // Custom tab not in YouTube's default items — create it
                NSInteger iconType = ymIconTypeForTabID(tabID);
                NSString *title = ymTitleForTabID(tabID);
                if (iconType > 0 && title) {
                    YTIPivotBarSupportedRenderers *newTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:pivotID title:title iconType:iconType];
                    if (newTab) [ordered addObject:newTab];
                }
            }
        }

        // Replace items with ordered set
        [items removeAllObjects];
        [items addObjectsFromArray:ordered];
    } else {
        // Legacy fallback: use old toggle-based logic
        NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
        NSMutableIndexSet *indicesToRemove = [NSMutableIndexSet indexSet];
        for (NSUInteger i = 0; i < items.count; i++) {
            YTIPivotBarSupportedRenderers *item = items[i];
            NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
            NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
            if ([pID isEqualToString:@"FEwhat_to_watch"] && IS_ENABLED(HideHomeTab)) [indicesToRemove addIndex:i];
            if ([pID isEqualToString:@"FEshorts"] && IS_ENABLED(HideShortsTab)) [indicesToRemove addIndex:i];
            if ([pID2 isEqualToString:@"FEuploads"] && IS_ENABLED(HideCreateButton)) [indicesToRemove addIndex:i];
            if ([pID isEqualToString:@"FEsubscriptions"] && IS_ENABLED(HideSubscriptTab)) [indicesToRemove addIndex:i];
        }
        [items removeObjectsAtIndexes:indicesToRemove];

        if (IS_ENABLED(AddsHistoryTab)) {
            YTIPivotBarSupportedRenderers *tab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForHistory] title:LOC(@"HISTORY_TAB") iconType:1];
            [items insertObject:tab atIndex:MIN((NSUInteger)1, items.count)];
        }
        if (IS_ENABLED(AddsGamingTab)) {
            YTIPivotBarSupportedRenderers *tab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForGamingDestination] title:LOC(@"GAMING_TAB") iconType:2];
            [items insertObject:tab atIndex:MIN((NSUInteger)1, items.count)];
        }
        if (IS_ENABLED(AddsSportsTab)) {
            YTIPivotBarSupportedRenderers *tab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForSportsDestination] title:LOC(@"SPORTS_TAB") iconType:3];
            [items insertObject:tab atIndex:MIN((NSUInteger)1, items.count)];
        }
        if (IS_ENABLED(AddsNotiTab)) {
            YTIPivotBarSupportedRenderers *tab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForNotificationsInbox] title:LOC(@"NOTI_TAB") iconType:4];
            [items insertObject:tab atIndex:MIN((NSUInteger)1, items.count)];
        }
    }

    %orig(renderer);
}
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
        NSInteger tabIndex = INTFORVAL(DefaultTab);
        if (tabIndex < 0 || tabIndex >= (NSInteger)pivotIdentifiers.count) tabIndex = 0;
        [self selectItemWithPivotIdentifier:pivotIdentifiers[tabIndex]];
        isTabSelected = YES;
    }
}
// Translucent tab bar
- (BOOL)isFrostedPivotBarPermitted {
    if (INTFORVAL(UseFrostedTabBar) == 1) {
        return YES;
    } else if (INTFORVAL(UseFrostedTabBar) == 2) {
        return NO;
    }
    return %orig;
}
%end
