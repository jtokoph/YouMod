#import "Headers.h"

// Modified from YTUnShorts (https://github.com/PoomSmart/YTUnShorts)
static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            if (IS_ENABLED(HideShortsShelf)) {
                YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
                YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
                NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
                NSIndexSet *removeItemsArrayIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                    YTIElementRenderer *elementRenderer = horizontalListSupportedRenderers.elementRenderer;
                    NSString *description = [elementRenderer description];
                    return [description containsString:@"shorts_video_cell"];
                }];
                if (removeItemsArrayIndexes.count > 0) {
                    [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
                }
            }
            return NO;
        }
        if ([sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            NSString *description = [sectionRenderer description];
            BOOL isShortsShelf = [description containsString:@"shorts_shelf.eml"];
            if (IS_ENABLED(HideShortsShelf) && IS_ENABLED(KeepShortsSubscript)) {
                if (isShortsShelf && ![description containsString:@"subscriptions"]) {
                    return YES;
                }
            } else if (IS_ENABLED(HideShortsShelf)) {
                if (isShortsShelf) {
                    return YES;
                }   
            }
            if (IS_ENABLED(HideHoriShelf) && [description containsString:@"horizontal_shelf.eml"] && ![description containsString:@"UCYfdidRxbB8Qhf0Nx7ioOYw"] && ![description containsString:@"FElibrary"] && ![description containsString:@"FEplaylist_aggregation"]) {
                return YES;
            }
        }
        return NO;
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

%hook YTInnerTubeCollectionViewController
- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    [self setValue:filteredArray(sectionRenderers) forKey:@"_sectionRenderers"];
    %orig;
}
- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    %orig(filteredArray(array));
}
%end

// Hide Subbar
%hook YTMySubsFilterHeaderView
- (void)setChipFilterView:(id)arg1 { if (!IS_ENABLED(HideSubbar)) %orig; }
%end

%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 { if (!IS_ENABLED(HideSubbar)) %orig; }
- (void)setFeedHeaderScrollMode:(int)arg1 { IS_ENABLED(HideSubbar) ? %orig(0) : %orig; }
%end

%hook YTChipCloudCell
- (void)layoutSubviews {
    if (self.superview && IS_ENABLED(HideSubbar)) {
        [self removeFromSuperview];
    } %orig;
}
%end

// Hide voice search button
%hook YTSearchViewController
- (void)viewDidLoad {
    %orig;
    if (IS_ENABLED(HideVoiceSearch)) {
        [self setValue:@(NO) forKey:@"_isVoiceSearchAllowed"];
    }
}
- (void)setSuggestions:(id)arg1 { if (!IS_ENABLED(HideSearchHis)) %orig; }
%end

// Hide search history and suggestions
%hook YTPersonalizedSuggestionsCacheProvider
- (id)activeCache { return IS_ENABLED(HideSearchHis) ? nil : %orig; }
%end
