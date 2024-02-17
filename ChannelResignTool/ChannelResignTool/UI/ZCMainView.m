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
    NSTextField *ipaPathField;
    NSButton *browseIpaPathButton;
    NSTextField *ipaSavePathField;
    NSButton *browseIpaSavePathButton;
    NSComboBox *certificateComboBox;
    NSComboBox *provisioningComboBox;
    
    NSTextField *appNameField;
    NSButton *radioButton;
    NSTextField *bundleIdField;
    NSButton *bundleIDButton;
    NSButton *ipaResignButton;
    
    NSTextField *appIconPathField;
    NSButton *browseAppIconPathButton;
    NSTextField *launchImagePathField;
    NSButton *browseLaunchImagePathButton;
    
    NSTableView *platformTableView;
    NSTextView *showSelectedPlatformField;
    NSButton *platformSignButton;
    
    NSTextView *logField;
    
    NSButton *cleanLogButton;
    NSButton *cleanPlatformButton;
    NSButton *cleanAllButton;
    
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
    NSView *platformView = [self setupPlatformUI:mubaoView];
    NSView *logView = [self setupLogUI:platformView];
    [self mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(logView);
    }];
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
    
    NSView *rightButtonView = [self setupRightButtonUIWithUIType:ZCMainUIType_chongqian withPreView:view buttonTitle:@"重签母包"];
    
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
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRegularSquareBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(platformTextView);
        make.right.equalTo(view).offset(-30);
        make.left.equalTo(platformTextView.mas_right).offset(20);
        make.height.mas_equalTo(40);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:@"渠道打包" attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    platformSignButton = button;
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(platformTextView).offset(20);
    }];
    return view;
}

- (NSView *)setupLogUI:(NSView *)preView {
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
    NSView *logView = [self setupLogViewUIWithUIType:ZCMainUIType_LogView withPreView:view];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(logView).offset(20);
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
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRoundedBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(textField.mas_right).offset(20);
        make.right.equalTo(view).offset(-20);
        make.width.mas_equalTo(80);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    if (uiType == ZCMainUIType_ipaPathField) {
        ipaPathField = textField;
    }
    if (uiType == ZCMainUIType_ipaSavePathField) {
        ipaSavePathField = textField;
    }
    if (uiType == ZCMainUIType_ipaPathField) {
        browseIpaPathButton = button;
    }
    if (uiType == ZCMainUIType_ipaSavePathField) {
        browseIpaSavePathButton = button;
    }
    if (uiType == ZCMainUIType_appIconPath) {
        appIconPathField = textField;
    }
    if (uiType == ZCMainUIType_launchImagePath) {
        launchImagePathField = textField;
    }
    if (uiType == ZCMainUIType_appIconPath) {
        browseAppIconPathButton = button;
    }
    if (uiType == ZCMainUIType_launchImagePath) {
        browseLaunchImagePathButton = button;
    }
    return view;
}
- (NSView *)setupFieldUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView withRightView:(NSView *)rightView textFieldString:(NSString *)textFieldString {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(rightView.mas_left).offset(-20);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    if (uiType == ZCMainUIType_appNameField) {
        appNameField = textField;
    }
    return view;
}
- (NSView *)setupButtonAndButtonUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView withRightView:(NSView *)rightView textFieldString:(NSString *)textFieldString buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
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
    [view addSubview:button0];
    [button0 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(button0.mas_right).offset(5);
    }];
    NSButton *button = [[NSButton alloc] init];
    [button setButtonType:NSButtonTypeRadio];
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(textField.mas_right).offset(20);
        make.right.equalTo(view).offset(-20);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    if (uiType == ZCMainUIType_bundleID) {
        radioButton = button0;
        bundleIdField = textField;
        bundleIDButton = button;
    }
    
    return view;
}
- (NSView *)setupComboBoxUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.mas_equalTo(40);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSComboBox *comboBox = [[NSComboBox alloc] init];
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
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithUIType:uiType labelString:@"渠道列表" forView:view];
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRoundedBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(customLabel);
        make.right.equalTo(view);
        make.width.mas_equalTo(80);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:@"清除列表" attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    
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
    
    if (uiType == ZCMainUIType_platformTable) {
        platformTableView = tableView;
        cleanPlatformButton = button;
    }
    
    return view;
}
- (NSView *)setupTextViewUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(preView.mas_right);
        make.top.equalTo(preView);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithUIType:uiType labelString:@"已选择渠道" forView:view];
    
    NSScrollView *textContainerView = [[NSScrollView alloc] init];
    [textContainerView setDrawsBackground:NO];//不画背景（背景默认画成白色）
    [textContainerView setHasVerticalScroller:YES];//有垂直滚动条
    //[_textContainerView setHasHorizontalScroller:YES];//有水平滚动条
//    textContainerView.autohidesScrollers = YES;//自动隐藏滚动条（滚动的时候出现）
    [view addSubview:textContainerView];
    [textContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(customLabel.mas_bottom).offset(10);
        make.left.equalTo(customLabel);
        make.width.mas_equalTo(250);
        make.height.mas_equalTo(250);
    }];
    
    NSTextView *textView = [[NSTextView alloc] init];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [textView setEditable:NO];
    [view addSubview:textView];
    [textContainerView setDocumentView:textView];
    [textView sizeToFit];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor labelColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(textContainerView);
    }];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.bottom.equalTo(textContainerView);
    }];
    
    if (uiType == ZCMainUIType_platformTextView) {
        showSelectedPlatformField = textView;
    }
    return view;
}
- (NSView *)setupLogViewUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(preView);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithUIType:uiType labelString:@"输出日志" forView:view];
    
    NSScrollView *textContainerView = [[NSScrollView alloc] init];
    [textContainerView setDrawsBackground:NO];//不画背景（背景默认画成白色）
    [textContainerView setHasVerticalScroller:YES];//有垂直滚动条
    //[_textContainerView setHasHorizontalScroller:YES];//有水平滚动条
//    textContainerView.autohidesScrollers = YES;//自动隐藏滚动条（滚动的时候出现）
    [view addSubview:textContainerView];
    [textContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(customLabel.mas_bottom).offset(10);
        make.left.equalTo(customLabel);
        make.right.equalTo(view).offset(-20);
        make.height.mas_equalTo(100);
    }];
    
    NSTextView *textView = [[NSTextView alloc] init];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [textView setEditable:NO];
    [view addSubview:textView];
    [textContainerView setDocumentView:textView];
    [textView sizeToFit];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor labelColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(textContainerView);
    }];
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRoundedBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(customLabel);
        make.right.equalTo(textContainerView);
        make.width.mas_equalTo(80);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:@"清除日志" attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(textContainerView);
    }];
    
    if (uiType == ZCMainUIType_LogView) {
        logField = textView;
        cleanLogButton = button;
    }
    return view;
}
- (NSView *)setupRightButtonUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(preView).offset(20);
        make.right.equalTo(preView).offset(-20);
        make.width.equalTo(preView).dividedBy(4);
        make.centerY.equalTo(preView);
    }];
    
    NSButton *button = [[NSButton alloc] init];
    button.bezelStyle = NSRegularSquareBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(view);
        make.width.height.equalTo(view).offset(-20);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    if (uiType == ZCMainUIType_chongqian) {
        ipaResignButton = button;
    }
    return view;
}

- (void)setupInit {
    bundleIDButton.state = NSControlStateValueOn;
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
        
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", platforms] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self->showSelectedPlatformField textStorage] setAttributedString:logAttributedString];
        [self->showSelectedPlatformField scrollRangeToVisible:NSMakeRange([self->showSelectedPlatformField string].length, 0)];
        
    });
}
- (void)showResigningPlatform:(NSString *)logString {
        
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", self->showSelectedPlatformFieldString, logString] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self->showSelectedPlatformField textStorage] setAttributedString:logAttributedString];
        [self->showSelectedPlatformField scrollRangeToVisible:NSMakeRange([self->showSelectedPlatformField string].length, 0)];
        
    });
}

#pragma mark - tableReload
- (void)tableReload {
    [platformTableView reloadData];
}


@end
