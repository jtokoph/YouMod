// YouModSettings.x — Reusable UIKit-based sub-page for YouMod settings sections
#import "Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Data Model

typedef NS_ENUM(NSInteger, YMRowType) {
    YMRowTypeToggle = 0,
    YMRowTypePicker,
    YMRowTypeAction,
    YMRowTypeHeader,
    YMRowTypeSegment
};

@interface YMSettingsItem : NSObject
@property (nonatomic, assign) YMRowType type;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSArray<NSString *> *pickerOptions;
@property (nonatomic, assign) NSInteger pickerDefault;
@property (nonatomic, copy) void (^action)(UIViewController *vc);
@property (nonatomic, strong) NSArray<NSNumber *> *segmentIcons;
+ (instancetype)toggleWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
+ (instancetype)pickerWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key options:(NSArray<NSString *> *)options defaultValue:(NSInteger)defaultValue;
+ (instancetype)actionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action;
+ (instancetype)headerWithTitle:(NSString *)title;
+ (instancetype)segmentWithTitle:(NSString *)title key:(NSString *)key icons:(NSArray<NSNumber *> *)icons defaultValue:(NSInteger)defaultValue;
@end

@implementation YMSettingsItem

+ (instancetype)toggleWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeToggle;
    item.title = title;
    item.subtitle = subtitle;
    item.key = key;
    return item;
}

+ (instancetype)pickerWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key options:(NSArray<NSString *> *)options defaultValue:(NSInteger)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypePicker;
    item.title = title;
    item.subtitle = subtitle;
    item.key = key;
    item.pickerOptions = options;
    item.pickerDefault = defaultValue;
    return item;
}

+ (instancetype)actionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeAction;
    item.title = title;
    item.subtitle = subtitle;
    item.action = action;
    return item;
}

+ (instancetype)headerWithTitle:(NSString *)title {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeHeader;
    item.title = title;
    return item;
}

+ (instancetype)segmentWithTitle:(NSString *)title key:(NSString *)key icons:(NSArray<NSNumber *> *)icons defaultValue:(NSInteger)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeSegment;
    item.title = title;
    item.key = key;
    item.segmentIcons = icons;
    item.pickerDefault = defaultValue;
    return item;
}

@end

#pragma mark - YMSubSettingsViewController

@interface YMSubSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (NSString *)navTitle;
- (void)setNavTitle:(NSString *)t;
- (NSArray<YMSettingsItem *> *)items;
- (void)setItems:(NSArray<YMSettingsItem *> *)items;
- (UIColor *)ymTextColor;
- (UIColor *)ymSecondaryColor;
@end

static const void *kYMTableViewKey = &kYMTableViewKey;
static const void *kYMNavTitleKey = &kYMNavTitleKey;
static const void *kYMItemsKey = &kYMItemsKey;
static const void *kYMSwitchKeyAssoc = &kYMSwitchKeyAssoc;

@implementation YMSubSettingsViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kYMTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kYMTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)navTitle { return objc_getAssociatedObject(self, kYMNavTitleKey); }
- (void)setNavTitle:(NSString *)t { objc_setAssociatedObject(self, kYMNavTitleKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray<YMSettingsItem *> *)items { return objc_getAssociatedObject(self, kYMItemsKey); }
- (void)setItems:(NSArray<YMSettingsItem *> *)items { objc_setAssociatedObject(self, kYMItemsKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (void)viewDidLoad {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLoad));

    self.title = self.navTitle;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.tableView.backgroundColor = [UIColor blackColor];
    } else {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }

    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&superStruct, @selector(viewWillAppear:), animated);
}

- (void)viewDidLayoutSubviews {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLayoutSubviews));

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        @try {
            id backButton = [self valueForKey:@"_backButton"];
            if ([backButton respondsToSelector:@selector(setTintColor:)]) {
                [backButton performSelector:@selector(setTintColor:) withObject:[UIColor whiteColor]];
            }
        } @catch (NSException *e) {}
    }
}

- (UIColor *)navBarForegroundColor {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor whiteColor];
    }
    return nil;
}

- (UIColor *)ymTextColor {
    return (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
        ? [UIColor whiteColor] : [UIColor labelColor];
}

- (UIColor *)ymSecondaryColor {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YMSettingsItem *item = self.items[indexPath.row];
    if (item.type == YMRowTypeToggle) {
        return [self toggleCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeAction) {
        return [self actionCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeHeader) {
        return [self headerCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeSegment) {
        return [self segmentCellForItem:item tableView:tableView];
    }
    return [self pickerCellForItem:item tableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YMSettingsItem *item = self.items[indexPath.row];
    if (item.type == YMRowTypeAction && item.action) {
        item.action(self);
    }
}

#pragma mark - Toggle Cell

- (UITableViewCell *)toggleCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    if (item.subtitle.length > 0) {
        cell.detailTextLabel.text = item.subtitle;
        cell.detailTextLabel.textColor = [self ymSecondaryColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = IS_ENABLED(item.key);
    sw.onTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    objc_setAssociatedObject(sw, kYMSwitchKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;

    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (key) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
    }
}

#pragma mark - Action Cell

- (UITableViewCell *)actionCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    if (item.subtitle.length > 0) {
        cell.detailTextLabel.text = item.subtitle;
        cell.detailTextLabel.textColor = [self ymSecondaryColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    return cell;
}

#pragma mark - Header Cell

- (UITableViewCell *)headerCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymSecondaryColor];
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    return cell;
}

#pragma mark - Segment Cell

- (UITableViewCell *)segmentCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:titleLabel];

    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < item.segmentIcons.count; i++) {
        [items addObject:@""];
    }
    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:items];

    for (NSInteger i = 0; i < (NSInteger)item.segmentIcons.count; i++) {
        YTIIcon *ytIcon = [NSClassFromString(@"YTIIcon") new];
        if (ytIcon) {
            ((void (*)(id, SEL, int))objc_msgSend)(ytIcon, @selector(setIconType:), [item.segmentIcons[i] intValue]);
            UIImage *iconImage = nil;
            if ([ytIcon respondsToSelector:@selector(iconImageWithColor:)]) {
                iconImage = [ytIcon iconImageWithColor:[UIColor whiteColor]];
            } else if ([ytIcon respondsToSelector:@selector(iconImageWithSelected:)]) {
                iconImage = [ytIcon iconImageWithSelected:NO];
            }
            if (iconImage) {
                [segment setImage:iconImage forSegmentAtIndex:i];
            }
        }
    }

    segment.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:item.key];
    segment.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
    segment.selectedSegmentTintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
    segment.layer.cornerRadius = 8.0;
    segment.clipsToBounds = YES;

    objc_setAssociatedObject(segment, kYMSwitchKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    segment.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:segment];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],

        [segment.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [segment.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [segment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [segment.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [segment.heightAnchor constraintEqualToConstant:36]
    ]];

    return cell;
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    NSString *key = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (key) {
        [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex forKey:key];
    }
}

#pragma mark - Picker Cell

- (UITableViewCell *)pickerCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    if (item.subtitle.length > 0) {
        cell.detailTextLabel.text = item.subtitle;
        cell.detailTextLabel.textColor = [self ymSecondaryColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    NSInteger currentValue = [[NSUserDefaults standardUserDefaults] integerForKey:item.key];
    NSInteger safeDefault = (item.pickerDefault >= 0 && item.pickerDefault < (NSInteger)item.pickerOptions.count)
        ? item.pickerDefault : 0;
    NSString *currentTitle = (currentValue >= 0 && currentValue < (NSInteger)item.pickerOptions.count)
        ? item.pickerOptions[currentValue]
        : item.pickerOptions[safeDefault];

    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [menuButton setTitle:currentTitle forState:UIControlStateNormal];
    [menuButton setTitleColor:[self ymSecondaryColor] forState:UIControlStateNormal];
    menuButton.titleLabel.font = [UIFont systemFontOfSize:15];
    menuButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [menuButton setImage:[UIImage systemImageNamed:@"chevron.up.chevron.down"] forState:UIControlStateNormal];
    menuButton.tintColor = [self ymSecondaryColor];

    NSMutableArray *menuActions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < (NSInteger)item.pickerOptions.count; i++) {
        NSString *optionTitle = item.pickerOptions[i];
        NSString *itemKey = item.key;
        UIAction *action = [UIAction actionWithTitle:optionTitle image:nil identifier:nil handler:^(__kindof UIAction *a) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:itemKey];
            [weakSelf.tableView reloadData];
        }];
        if (i == currentValue) {
            action.state = UIMenuElementStateOn;
        }
        [menuActions addObject:action];
    }

    menuButton.menu = [UIMenu menuWithTitle:item.title children:menuActions];
    menuButton.showsMenuAsPrimaryAction = YES;
    [menuButton sizeToFit];
    cell.accessoryView = menuButton;

    return cell;
}

#pragma mark - Table View Footer

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 16;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

@end

#pragma mark - Convenience Factory Functions

YMSettingsItem *YMToggle(NSString *title, NSString *subtitle, NSString *key) {
    return [YMSettingsItem toggleWithTitle:title subtitle:subtitle key:key];
}

YMSettingsItem *YMPicker(NSString *title, NSString *subtitle, NSString *key, NSArray<NSString *> *options, NSInteger defaultValue) {
    return [YMSettingsItem pickerWithTitle:title subtitle:subtitle key:key options:options defaultValue:defaultValue];
}

YMSettingsItem *YMAction(NSString *title, NSString *subtitle, void (^action)(UIViewController *vc)) {
    return [YMSettingsItem actionWithTitle:title subtitle:subtitle action:action];
}

YMSettingsItem *YMHeader(NSString *title) {
    return [YMSettingsItem headerWithTitle:title];
}

YMSettingsItem *YMSegment(NSString *title, NSString *key, NSArray<NSNumber *> *icons, NSInteger defaultValue) {
    return [YMSettingsItem segmentWithTitle:title key:key icons:icons defaultValue:defaultValue];
}

#pragma mark - Entry Point

void YMPushSubSettings(NSString *title, NSArray<YMSettingsItem *> *items, id settingsVC, id parentResponder) {
    Class styledClass = objc_getClass("YMSubSettingsViewControllerStyled");
    if (!styledClass) styledClass = [YMSubSettingsViewController class];

    YMSubSettingsViewController *vc = (YMSubSettingsViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];
    vc.navTitle = title;
    vc.items = items;
    [settingsVC pushViewController:vc];
}

#pragma mark - Runtime Class Registration

%ctor {
    Class ytStyled = %c(YTStyledViewController);
    if (ytStyled) {
        Class ymStyled = objc_allocateClassPair(ytStyled, "YMSubSettingsViewControllerStyled", 0);
        if (ymStyled) {
            unsigned int count = 0;
            Method *methods = class_copyMethodList([YMSubSettingsViewController class], &count);
            for (unsigned int i = 0; i < count; i++) {
                class_addMethod(ymStyled, method_getName(methods[i]), method_getImplementation(methods[i]), method_getTypeEncoding(methods[i]));
            }
            free(methods);

            unsigned int propCount = 0;
            objc_property_t *props = class_copyPropertyList([YMSubSettingsViewController class], &propCount);
            for (unsigned int i = 0; i < propCount; i++) {
                unsigned int attrCount = 0;
                objc_property_attribute_t *attrs = property_copyAttributeList(props[i], &attrCount);
                class_addProperty(ymStyled, property_getName(props[i]), attrs, attrCount);
                free(attrs);
            }
            free(props);

            objc_registerClassPair(ymStyled);
        }
    }
}
