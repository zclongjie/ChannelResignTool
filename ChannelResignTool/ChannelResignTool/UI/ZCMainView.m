//
//  ZCMainView.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#import "ZCMainView.h"
#import "Masonry.h"
#import "NSView+ZCUtil.h"
#import "ZCProvisioningProfile.h"
#import "ZCDateFormatterUtil.h"
#import "ZCFileHelper.h"
#import "PlatformRowView.h"


@interface ZCMainView ()<NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate, PlatformRowViewDelegate>
{
    NSComboBox *certificateComboBox;
    NSComboBox *provisioningComboBox;
    
    NSString *showSelectedPlatformFieldString;
}
@end

@implementation ZCMainView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}
- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [NSColor windowBackgroundColor];
        [self setupUI];
    }
    return self;
}
- (void)viewDidMoveToSuperview {
    [super viewDidMoveToSuperview];
    // 在这里执行视图完全加载后的操作
    [self setupInit];
}

- (void)setupUI {
    NSView *customView = [self setupCustomUI];
    NSView *mubaoView = [self setupMubaoUI:customView];
    [self setupPlatformUI:mubaoView];
}
- (NSView *)setupCustomUI {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self);
    }];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor labelColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(view).offset(10);
        make.right.bottom.equalTo(view).offset(-10);
    }];
    NSTextField *customLabel = [self setupTitleUIWithUIType:ZCMainUIType_Custom labelString:@"公共参数（必填）" forView:view];
    NSView *ipaPathView = [self setupFieldAndButtonUIWithUIType:ZCMainUIType_ipaPathField withPreView:customLabel textFieldString:@"原始ipa或app文件路径" buttonTitle:@"浏 览"];
    NSView *ipaSavePathView = [self setupFieldAndButtonUIWithUIType:ZCMainUIType_ipaSavePathField withPreView:ipaPathView textFieldString:@"生成IPA文件保存路径" buttonTitle:@"浏 览"];
    NSView *certificateView = [self setupComboBoxUIWithUIType:ZCMainUIType_certificateComboBox withPreView:ipaSavePathView];
    NSView *provisioningView = [self setupComboBoxUIWithUIType:ZCMainUIType_provisioningComboBox withPreView:certificateView];
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(provisioningView).offset(10);
    }];
    return view;
}
- (NSView *)setupMubaoUI:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.top.equalTo(preView.mas_bottom);
    }];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor labelColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(view).offset(10);
        make.right.bottom.equalTo(view).offset(-10);
    }];
    NSTextField *customLabel = [self setupTitleUIWithUIType:ZCMainUIType_Custom labelString:@"重签母包" forView:view];
    
    NSView *rightButtonView = [self setupRightButtonUIWithUIType:ZCMainUIType_chongqian withPreView:view buttonTitle:@"重 签"];
    
    NSView *appNameView = [self setupFieldUIWithUIType:ZCMainUIType_appNameField withPreView:customLabel withRightView:rightButtonView textFieldString:@"修改App显示名称（选填）"];
    NSView *bundleIDView = [self setupButtonAndButtonUIWithUIType:ZCMainUIType_bundleID withPreView:appNameView withRightView:rightButtonView textFieldString:@"修改BundleID, 不填则默认使用App中BundleID" buttonTitle:@"使用pro证书中的BundleID"];
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(bundleIDView).offset(10);
    }];
    
    
    
    return view;
}
- (NSView *)setupPlatformUI:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.top.equalTo(preView.mas_bottom);
    }];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor labelColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(view).offset(10);
        make.right.bottom.equalTo(view).offset(-10);
    }];
    NSTextField *customLabel = [self setupTitleUIWithUIType:ZCMainUIType_Custom labelString:@"打渠道包" forView:view];
    NSView *appIconPathView = [self setupFieldAndButtonUIWithUIType:ZCMainUIType_appIconPath withPreView:customLabel textFieldString:@"AppIcon文件路径" buttonTitle:@"浏 览"];
    NSView *launchImagePathView = [self setupFieldAndButtonUIWithUIType:ZCMainUIType_launchImagePath withPreView:appIconPathView textFieldString:@"LaunchImage文件路径（选填）" buttonTitle:@"浏 览"];
    NSView *tableView = [self setupTableUIWithUIType:ZCMainUIType_platformTable withPreView:launchImagePathView];
    NSView *platformTextView = [self setupTextViewUIWithUIType:ZCMainUIType_platformTextView withPreView:tableView];
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(tableView).offset(20);
    }];
    return view;
}

- (NSTextField *)setupTitleUIWithUIType:(ZCMainUIType)uiType labelString:(NSString *)labelString forView:(NSView *)view {
    NSTextField *label = [[NSTextField alloc] init];
    label.editable = NO;
    label.bordered = NO;
    label.stringValue = labelString;
    label.font = [NSFont systemFontOfSize:18];
    label.backgroundColor = [NSColor clearColor];
    [view addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(view).offset(20);
        make.left.equalTo(view).offset(20);
    }];
    return label;
}
- (NSView *)setupFieldAndButtonUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView textFieldString:(NSString *)textFieldString buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    textField.customTag = view.customTag + 1;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRoundedBezelStyle;
    button.customTag = view.customTag + 2;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(textField.mas_right).offset(20);
        make.right.equalTo(view).offset(-20);
        make.width.mas_equalTo(80);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    return view;
}
- (NSView *)setupFieldUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView withRightView:(NSView *)rightView textFieldString:(NSString *)textFieldString {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(rightView.mas_left).offset(-20);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    textField.customTag = view.customTag + 1;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    return view;
}
- (NSView *)setupButtonAndButtonUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView withRightView:(NSView *)rightView textFieldString:(NSString *)textFieldString buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(rightView.mas_left).offset(-20);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    NSButton *button0 = [[NSButton alloc] init];
    [button0 setButtonType:NSButtonTypeRadio];
    [button0 setTitle:@""];
    button0.customTag = view.customTag + 1;
    [view addSubview:button0];
    [button0 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    textField.customTag = view.customTag + 2;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(button0.mas_right).offset(5);
    }];
    NSButton *button = [[NSButton alloc] init];
    [button setButtonType:NSButtonTypeRadio];
    button.customTag = view.customTag + 3;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(textField.mas_right).offset(20);
        make.right.equalTo(view).offset(-20);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    return view;
}
- (NSView *)setupComboBoxUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSComboBox *comboBox = [[NSComboBox alloc] init];
    comboBox.customTag = view.customTag + 1;
    [view addSubview:comboBox];
    [comboBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    if (uiType == ZCMainUIType_certificateComboBox) {
        comboBox.placeholderString = @"选择一个签名证书";
        certificateComboBox = comboBox;
    } else if (uiType == ZCMainUIType_provisioningComboBox) {
        comboBox.placeholderString = @"选择一个描述文件";
        provisioningComboBox = comboBox;
    }
    comboBox.usesDataSource = YES;
    comboBox.dataSource = self;
    comboBox.delegate = self;
    return view;
}
- (NSView *)setupTableUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithUIType:uiType labelString:@"渠道列表" forView:view];
    
    NSScrollView *tableContainerView = [[NSScrollView alloc] init];
    [tableContainerView setDrawsBackground:NO];//不画背景（背景默认画成白色）
    [tableContainerView setHasVerticalScroller:YES];//有垂直滚动条
    //[_tableContainer setHasHorizontalScroller:YES];//有水平滚动条
//    tableContainerView.autohidesScrollers = YES;//自动隐藏滚动条（滚动的时候出现）
    [view addSubview:tableContainerView];
    [tableContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(customLabel.mas_bottom).offset(10);
        make.left.equalTo(customLabel);
        make.width.mas_equalTo(250);
        make.height.mas_equalTo(250);
    }];
    
    NSTableView *tableView = [[NSTableView alloc] init];
    tableView.customTag = view.customTag + 1;
    tableView.headerView = nil;
    tableView.allowsColumnReordering = NO;
    tableView.allowsColumnResizing = NO;
    tableView.focusRingType = NSFocusRingTypeNone;
    tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"Column"];
    [tableView addTableColumn:column];
    [tableContainerView setDocumentView:tableView];
    NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PlatformRowView" bundle:nil];
    [tableView registerNib:nib forIdentifier:@"PlatformRowView"];
    tableView.dataSource = self;
    tableView.delegate = self;

    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor labelColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(tableContainerView);
    }];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.bottom.equalTo(tableContainerView);
    }];
    
    return view;
}
- (NSView *)setupTextViewUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(preView.mas_right);
        make.top.equalTo(preView);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithUIType:uiType labelString:@"已选择渠道" forView:view];
    NSTableView *textView = [[NSTableView alloc] init];
    textView.customTag = view.customTag + 1;
    [view addSubview:textView];
    [textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(customLabel.mas_bottom);
        make.left.equalTo(view).offset(20);
        make.width.mas_equalTo(200);
        make.height.mas_equalTo(200);
    }];
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.bottom.equalTo(textView);
    }];
    return view;
}
- (NSView *)setupRightButtonUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
    view.customTag = uiType * 10;
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(preView).offset(20);
        make.right.equalTo(preView).offset(-20);
        make.width.equalTo(preView).dividedBy(4);
        make.centerY.equalTo(preView);
    }];
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRegularSquareBezelStyle;
    button.customTag = view.customTag + 1;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(view);
        make.width.height.equalTo(view).offset(-20);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    return view;
}

- (void)setupInit {
    NSButton *button = (NSButton *)[self findSuitableView:ZCMainUIType_bundleID * 10 + 1];
    button.state = NSControlStateValueOn;
}
- (id)findSuitableView:(NSInteger)customTag {
    NSView *findView = nil;
    for (NSView *view0 in self.subviews) {
        findView = view0;
        if (view0.customTag == customTag) {
            return view0;
        }
        for (NSView *view1 in view0.subviews) {
            if (view1.customTag == customTag) {
                return view1;
            }
            for (NSView *view2 in view1.subviews) {
                if (view2.customTag == customTag) {
                    return view2;
                }
                for (NSView *view3 in view2.subviews) {
                    if (view3.customTag == customTag) {
                        return view3;
                    }
                }
            }
        }
    }
    return nil;
}

#pragma mark - NSComboBoxDataSource, NSComboBoxDelegate
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    NSInteger count = 0;
    if ([comboBox isEqual:certificateComboBox]) {
        count = self.certificatesArray.count;
    } else if ([comboBox isEqual:provisioningComboBox]) {
        count = self.provisioningArray.count;
    }
    return count;
}
- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    id item = nil;
    if ([comboBox isEqual:certificateComboBox]) {
        if (self.certificatesArray.count > index) {
            item = self.certificatesArray[index];
        }
    } else if ([comboBox isEqual:provisioningComboBox]) {
        if (self.provisioningArray.count > index) {
            ZCProvisioningProfile *profile = self.provisioningArray[index];
            item = [NSString stringWithFormat:@"%@(%@) %@", profile.name, profile.bundleIdentifier, [[ZCDateFormatterUtil sharedFormatter] yyyyMMddHHmmssForDate:profile.creationDate]];
        }
    }
    return item;
}
- (void)setCertificatesArray:(NSArray *)certificatesArray {
    _certificatesArray = certificatesArray;
    [certificateComboBox reloadData];
    [certificateComboBox selectItemAtIndex:0];//默认选择第一个
}
- (void)setProvisioningArray:(NSArray *)provisioningArray {
    _provisioningArray = provisioningArray;
    [provisioningComboBox reloadData];
    [provisioningComboBox selectItemAtIndex:0];//默认选择第一个
}

#pragma mark - NSTableViewDataSource, NSTableViewDelegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger count = [[ZCFileHelper sharedInstance] platformArray].count;
    return count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PlatformRowView *rowView = [tableView makeViewWithIdentifier:@"PlatformRowView" owner:self];
    if (!rowView) {
        rowView = [[PlatformRowView alloc] init];
    }
    rowView.delegate = self;
    ZCPlatformDataJsonModel *model = [[ZCFileHelper sharedInstance] platformArray][row];
    rowView.model = model;
    return rowView;
}
#pragma mark - PlatformRowViewDelegate
- (void)platformRowViewButtonClick:(ZCPlatformDataJsonModel *)selectModel {
    NSMutableArray *selectPlatformNameArray = @[].mutableCopy;
    [[[ZCFileHelper sharedInstance] platformArray] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        ZCPlatformDataJsonModel *model = (ZCPlatformDataJsonModel *)obj;
        if (model.isSelect) {
            [selectPlatformNameArray addObject:model.name];
        }
    }];
    [self showSelectPlatformView:selectPlatformNameArray];
}
- (void)showSelectPlatformView:(NSMutableArray *)selectPlatformNameArray {
    if (selectPlatformNameArray.count) {
        NSString *platforms = [selectPlatformNameArray componentsJoinedByString:@"、"];
        [self showSelectedPlatform:[NSString stringWithFormat:@"已选择 %ld 个渠道：\n%@\n", selectPlatformNameArray.count, platforms]];
    } else {
        [self showSelectedPlatform:@""];
    }
}
- (void)showSelectedPlatform:(NSString *)platforms {
    showSelectedPlatformFieldString = platforms;
    
    NSTextView *textView = (NSTextView *)[self findSuitableView:ZCMainUIType_platformTextView * 10 + 1];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", platforms] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[textView textStorage] setAttributedString:logAttributedString];
        [textView scrollRangeToVisible:NSMakeRange([textView string].length, 0)];
        
    });
}
- (void)showResigningPlatform:(NSString *)logString {
    
    NSTextView *textView = (NSTextView *)[self findSuitableView:ZCMainUIType_platformTextView * 10 + 1];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", self->showSelectedPlatformFieldString, logString] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[textView textStorage] setAttributedString:logAttributedString];
        [textView scrollRangeToVisible:NSMakeRange([textView string].length, 0)];
        
    });
}

#pragma mark - tableReload
- (void)tableReload {
    NSTableView *tableView = (NSTableView *)[self findSuitableView:ZCMainUIType_platformTable * 10 + 1];
    [tableView reloadData];
}


@end
