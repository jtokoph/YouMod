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
    if (type == 1 || type == 2 || type == 3 || type == 4 || type == 5 || type == 6 || type == 7 || type == 8 || type == 9) {
        NSString *imageName;
        if (type == 1) imageName = isSelected ? @"icons/history_selected" : @"icons/history";
        else if (type == 2) imageName = isSelected ? @"icons/gaming_selected" : @"icons/gaming";
        else if (type == 3) imageName = isSelected ? @"icons/sports_selected" : @"icons/sports";
        else if (type == 4) imageName = isSelected ? @"icons/noti_selected" : @"icons/noti";
        else if (type == 5) imageName = isSelected ? @"icons/news_selected" : @"icons/news";
        else if (type == 6) imageName = isSelected ? @"icons/music_selected" : @"icons/music";
        else if (type == 7) imageName = isSelected ? @"icons/watchlater_selected" : @"icons/watchlater";
        else if (type == 8) imageName = isSelected ? @"icons/playlist_selected" : @"icons/playlist";
        else if (type == 9) imageName = isSelected ? @"icons/like_selected" : @"icons/like";
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
    if ([tabID isEqualToString:@"news"]) return @"UCYfdidRxbB8Qhf0Nx7ioOYw"; // FEnews_destination
    if ([tabID isEqualToString:@"music"]) return @"UC-9-kyTW8ZkZNDHQJ6FgpwQ";
    if ([tabID isEqualToString:@"watchlater"]) return @"VLWL";
    if ([tabID isEqualToString:@"playlist"]) return @"FEplaylist_aggregation";
    if ([tabID isEqualToString:@"like"]) return @"VLLL";
    return nil;
}

static NSInteger ymIconTypeForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return 1;
    if ([tabID isEqualToString:@"gaming"]) return 2;
    if ([tabID isEqualToString:@"sports"]) return 3;
    if ([tabID isEqualToString:@"notifications"]) return 4;
    if ([tabID isEqualToString:@"news"]) return 5;
    if ([tabID isEqualToString:@"music"]) return 6;
    if ([tabID isEqualToString:@"watchlater"]) return 7;
    if ([tabID isEqualToString:@"playlist"]) return 8;
    if ([tabID isEqualToString:@"like"]) return 9;
    return 0;
}

static NSString *ymTitleForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return LOC(@"HISTORY_TAB");
    if ([tabID isEqualToString:@"gaming"]) return LOC(@"GAMING_TAB");
    if ([tabID isEqualToString:@"sports"]) return LOC(@"SPORTS_TAB");
    if ([tabID isEqualToString:@"notifications"]) return LOC(@"NOTI_TAB");
    if ([tabID isEqualToString:@"news"]) return LOC(@"NEWS_TAB");
    if ([tabID isEqualToString:@"music"]) return LOC(@"MUSIC_TAB");
    if ([tabID isEqualToString:@"watchlater"]) return LOC(@"WATCH_LATER_TAB");
    if ([tabID isEqualToString:@"playlist"]) return LOC(@"PLAYLIST_TAB");
    if ([tabID isEqualToString:@"like"]) return LOC(@"LIKE_TAB");
    return nil;
}

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
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
        // Build pivot identifiers from enabled tabs (skip Create — matches Settings.x segment logic)
        NSMutableArray *pivotIdentifiers = [NSMutableArray array];
        NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
        if (savedOrder.count > 0) {
            for (NSDictionary *entry in savedOrder) {
                if (![entry[@"enabled"] boolValue]) continue;
                NSString *tabID = entry[@"id"];
                if ([tabID isEqualToString:@"create"]) continue;
                NSString *pivot = ymPivotIDForTabID(tabID);
                if (pivot) [pivotIdentifiers addObject:pivot];
            }
        }
        if (pivotIdentifiers.count == 0) {
            pivotIdentifiers = [@[@"FEwhat_to_watch", @"FEshorts", @"FEsubscriptions", @"FElibrary"] mutableCopy];
        }

        NSInteger tabIndex = INTFORVAL(DefaultTab);
        if (tabIndex < 0) tabIndex = 0;
        if (tabIndex >= (NSInteger)pivotIdentifiers.count) tabIndex = MAX(0, (NSInteger)pivotIdentifiers.count - 1);
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
