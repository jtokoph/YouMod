#import "Headers.h"

static int localPageStyle;

// OLEDKeyboard (https://github.com/dayanch96/OledKeyboard)
static BOOL isDarkMode(UIView *view) {
    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) {
        return view._mapkit_isDarkModeEnabled;
    }
    return view._viewControllerForAncestor.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

// OLED theme (uYouEnhanced)
%group OLEDTheme
%hook YTColor
+ (UIColor *)black0 { return [UIColor blackColor]; }
+ (UIColor *)black1 { return [UIColor blackColor]; }
+ (UIColor *)black2 { return [UIColor blackColor]; }
+ (UIColor *)black3 { return [UIColor blackColor]; }
+ (UIColor *)black4 { return [UIColor blackColor]; }
%end

%hook YTCommonColorPalette
- (UIColor *)baseBackground { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)brandBackgroundSolid { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)brandBackgroundPrimary { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)brandBackgroundSecondary { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)raisedBackground { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)staticBrandBlack { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)generalBackgroundA { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (NSInteger)pageStyle {
    int value = %orig;
    localPageStyle = value;
    return value;
}
%end

%hook YTInnerTubeCollectionViewController
- (UIColor *)backgroundColor:(NSInteger)pageStyle { return pageStyle == 1 ? [UIColor blackColor] : %orig; }
%end

%hook UITableViewCell
- (void)_layoutSystemBackgroundView {
    %orig;
    if (localPageStyle != 1) return;
    UIView *systemBackgroundView = [self valueForKey:@"_systemBackgroundView"];
    NSString *backgroundViewKey = class_getInstanceVariable(systemBackgroundView.class, "_colorView") ? @"_colorView" : @"_backgroundView";
    ((UIView *)[systemBackgroundView valueForKey:backgroundViewKey]).backgroundColor = [UIColor blackColor];
}
- (void)_layoutSystemBackgroundView:(BOOL)arg1 {
    %orig;
    if (localPageStyle != 1) return;
    ((UIView *)[[self valueForKey:@"_systemBackgroundView"] valueForKey:@"_colorView"]).backgroundColor = [UIColor blackColor];
}
%end

// There is YTBotttomSheetController, but I can't reprecate it yet.
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if (localPageStyle != 1) return;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.elements.components.comment_composer",
        @"eml.cvr",
        @"id.subs.subscriptions_channel_bar",
        @"eml.live_chat_text_message", nil
    ];  
    if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor blackColor];       
    if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.text_field"]) self.superview.backgroundColor = [UIColor blackColor];
    // Action dialog
    UIResponder *responder = self.nextResponder;
    while (responder != nil) {
        if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)]) {
            UIViewController *vc = (UIViewController *)responder;
            vc.view.backgroundColor = [UIColor blackColor];
            break;
        }
        responder = responder.nextResponder;
    }
    /*
    if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
        self.backgroundColor = [UIColor blackColor];
        self.superview.backgroundColor = [UIColor blackColor];
    }
    if (localPageStyle == 1) {
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.text_field"]) self.superview.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
            self.backgroundColor = [UIColor blackColor];
            self.superview.backgroundColor = [UIColor blackColor];
        }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.comment_composer"]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"brand_promo.view"]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"eml.cvr"]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"id.subs.subscriptions_channel_bar"]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"]) self.backgroundColor = [UIColor blackColor];
        if ([self isKindOfClass:NSClassFromString(@"_ASDisplayView")] && [self isInsideViewControllerOfClass:@"YTActionSheetDialogViewController"]) self.backgroundColor = [UIColor blackColor];
    } else {
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.text_field"]) self.superview.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
            self.backgroundColor = [UIColor clearColor];
            self.superview.backgroundColor = [UIColor clearColor];
        }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.comment_composer"]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"brand_promo.view"]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"eml.cvr"]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"id.subs.subscriptions_channel_bar"]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"]) self.backgroundColor = [UIColor clearColor];
        if ([self isKindOfClass:NSClassFromString(@"_ASDisplayView")] && [self isInsideViewControllerOfClass:@"YTActionSheetDialogViewController"]) self.backgroundColor = [UIColor clearColor];
    }
    */
}
%end

%hook ASCollectionView
- (void)didMoveToWindow {
    %orig;
    if (localPageStyle != 1) return;
    NSSet *blackViews = [NSSet setWithObjects:
        @"eml.chip_bar_collection",
        @"subs_channel_bar.collection", nil
    ];  
    if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor blackColor];
    if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.more_drawer_collection"]) self.superview.backgroundColor = [UIColor blackColor];
    /*
    if (localPageStyle == 1) {
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.more_drawer_collection"]) self.superview.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"eml.chip_bar_collection"]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor blackColor];
    } else {
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.more_drawer_collection"]) self.superview.backgroundColor = [UIColor whiteColor];
        if ([self.accessibilityIdentifier isEqualToString:@"eml.chip_bar_collection"]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor clearColor];
    }
    */
}
%end
%end

%group OLEDKeyboard
%hook UIKeyboard
- (void)displayLayer:(id)arg1 {
    %orig;
    self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
}
%end

%hook UIPredictionViewController
- (id)_currentTextSuggestions {
    UIKeyboard *keyboard = [%c(UIKeyboard) activeKeyboard];
    if (isDarkMode(keyboard)) {
        [self.view setBackgroundColor:[UIColor blackColor]];
        keyboard.backgroundColor = [UIColor blackColor];
    } else {
        [self.view setBackgroundColor:[UIColor clearColor]];
        keyboard.backgroundColor = [UIColor clearColor];
    }
    return %orig;
}
%end

%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
}
%end

// Since we can't hook a private framework class from UIKit, we check the class name through the nearest available from UIKit class
%hook UIInputView
- (void)layoutSubviews {
    %orig;
    if ([self isKindOfClass:NSClassFromString(@"TUIEmojiSearchInputView")] // Emoji searching panel
     || [self isKindOfClass:NSClassFromString(@"_SFAutoFillInputView")]) { // Autofill password
        self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }
}
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (isDarkMode(self)) {
        self.backgroundEffects = nil;
        self.backgroundColor = [UIColor blackColor];
    }
}
%end
%end

%ctor {
    if (IS_ENABLED(OLEDTheme)) {
        %init(OLEDTheme);
    }
    if (IS_ENABLED(OLEDKeyboard)) {
        %init(OLEDKeyboard);
    }
}
