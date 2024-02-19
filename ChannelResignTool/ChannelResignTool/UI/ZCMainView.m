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
    NSString *showSelectedPlatformFieldString;
    BOOL tableDisenable;
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
        make.top.equalTo(self).offset(5);
        make.left.right.equalTo(self);
    }];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(view).offset(5);
        make.left.equalTo(view).offset(10);
        make.right.equalTo(view).offset(-10);
        make.bottom.equalTo(view).offset(-5);
    }];
    NSTextField *customLabel = [self setupTitleUIWithLabelString:@"公共参数（必填）" forView:view];
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
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(view).offset(5);
        make.left.equalTo(view).offset(10);
        make.right.equalTo(view).offset(-10);
        make.bottom.equalTo(view).offset(-5);
    }];
    NSTextField *customLabel = [self setupTitleUIWithLabelString:@"重签母包" forView:view];
    NSButton *button = [NSButton buttonWithTitle:@"重签母包" target:self action:@selector(buttonAction:)];
    button.tag = ZCMainUIType_chongqian;
    button.bezelStyle = NSRegularSquareBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(view).offset(-30);
        make.width.mas_equalTo(80);
        make.height.mas_equalTo(30);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:@"重签母包" attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    self.ipaResignButton_ = button;
    
    NSView *appNameView = [self setupFieldUIWithPreView:customLabel withRightView:button textFieldString:@"修改App显示名称（选填）"];
    NSView *bundleIDView = [self setupButtonAndButtonUIWithPreView:appNameView withRightView:button textFieldString:@"修改BundleID, 不填则默认使用App中BundleID" buttonTitle:@"使用pro证书中的BundleID"];
    
    [button mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(bundleIDView).offset(-10);
    }];
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
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(view).offset(5);
        make.left.equalTo(view).offset(10);
        make.right.equalTo(view).offset(-10);
        make.bottom.equalTo(view).offset(-5);
    }];
    NSTextField *customLabel = [self setupTitleUIWithLabelString:@"打渠道包" forView:view];
    NSView *appIconPathView = [self setupFieldAndButtonUIWithUIType:ZCMainUIType_appIconPath withPreView:customLabel textFieldString:@"AppIcon文件路径" buttonTitle:@"浏 览"];
    NSView *launchImagePathView = [self setupFieldAndButtonUIWithUIType:ZCMainUIType_launchImagePath withPreView:appIconPathView textFieldString:@"LaunchImage文件路径（选填）" buttonTitle:@"浏 览"];
    
    NSButton *button = [NSButton buttonWithTitle:@"渠道打包" target:self action:@selector(buttonAction:)];
    button.tag = ZCMainUIType_platformResign;
    button.bezelStyle = NSRegularSquareBezelStyle;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(view).offset(-30);
        make.width.mas_equalTo(80);
        make.height.mas_equalTo(30);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:@"渠道打包" attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    self.platformSignButton_ = button;
    
    NSView *tableView = [self setupTableUIWithPreView:launchImagePathView];
    NSView *platformTextView = [self setupTextViewUIWithPreView:tableView withRightView:button];
    
    [button mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(platformTextView);
    }];
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(platformTextView).offset(15);
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
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(view).offset(5);
        make.left.equalTo(view).offset(10);
        make.right.bottom.equalTo(view).offset(-10);
    }];
    NSView *logView = [self setupLogViewUIWithPreView:view];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(logView).offset(20);
    }];
    return view;
}


- (NSTextField *)setupTitleUIWithLabelString:(NSString *)labelString forView:(NSView *)view {
    NSTextField *label = [[NSTextField alloc] init];
    label.editable = NO;
    label.bordered = NO;
    label.stringValue = labelString;
    label.font = [NSFont systemFontOfSize:18];
    label.backgroundColor = [NSColor clearColor];
    [view addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(view).offset(10);
        make.left.equalTo(view).offset(20);
    }];
    return label;
}
- (NSView *)setupFieldAndButtonUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView textFieldString:(NSString *)textFieldString buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.mas_equalTo(30);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    
    NSButton *button = [NSButton buttonWithTitle:buttonTitle target:self action:@selector(buttonAction:)];
    button.tag = uiType;
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
        self.ipaPathField_ = textField;
    }
    if (uiType == ZCMainUIType_ipaSavePathField) {
        self.ipaSavePathField_ = textField;
    }
    if (uiType == ZCMainUIType_ipaPathField) {
        self.browseIpaPathButton_ = button;
    }
    if (uiType == ZCMainUIType_ipaSavePathField) {
        self.browseIpaSavePathButton_ = button;
    }
    if (uiType == ZCMainUIType_appIconPath) {
        self.appIconPathField_ = textField;
    }
    if (uiType == ZCMainUIType_launchImagePath) {
        self.launchImagePathField_ = textField;
    }
    if (uiType == ZCMainUIType_appIconPath) {
        self.browseAppIconPathButton_ = button;
    }
    if (uiType == ZCMainUIType_launchImagePath) {
        self.browseLaunchImagePathButton_ = button;
    }
    return view;
}
- (NSView *)setupFieldUIWithPreView:(NSView *)preView withRightView:(NSView *)rightView textFieldString:(NSString *)textFieldString {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(rightView.mas_left);
        make.height.mas_equalTo(30);
        make.top.equalTo(preView.mas_bottom);
    }];
    
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = textFieldString;
    [view addSubview:textField];
    [textField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(view);
        make.left.equalTo(view).offset(20);
    }];
    self.appNameField_ = textField;
    return view;
}
- (NSView *)setupButtonAndButtonUIWithPreView:(NSView *)preView withRightView:(NSView *)rightView textFieldString:(NSString *)textFieldString buttonTitle:(NSString *)buttonTitle {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(rightView.mas_left);
        make.height.mas_equalTo(30);
        make.top.equalTo(preView.mas_bottom);
    }];
    NSButton *button0 = [NSButton buttonWithTitle:@"" target:self action:@selector(buttonAction:)];
    button0.tag = ZCMainUIType_changeBundleID;
    [button0 setButtonType:NSButtonTypeRadio];
    button0.state = NSControlStateValueOn;
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
    NSButton *button = [NSButton buttonWithTitle:buttonTitle target:self action:@selector(buttonAction:)];
    button.tag = ZCMainUIType_proBundleID;
    [button setButtonType:NSButtonTypeRadio];
    button.state = NSControlStateValueOff;
    [view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(view);
        make.left.equalTo(textField.mas_right).offset(20);
        make.right.equalTo(view).offset(-20);
    }];
    NSAttributedString *nameAttribute = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{NSForegroundColorAttributeName:[NSColor labelColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    [button setAttributedTitle:nameAttribute];
    
    self.radioButton_ = button0;
    self.bundleIdField_ = textField;
    self.bundleIDButton_ = button;
    
    return view;
}
- (NSView *)setupComboBoxUIWithUIType:(ZCMainUIType)uiType withPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.mas_equalTo(30);
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
        self.certificateComboBox_ = comboBox;
    } else if (uiType == ZCMainUIType_provisioningComboBox) {
        comboBox.placeholderString = @"选择一个描述文件";
        self.provisioningComboBox_ = comboBox;
    }
    comboBox.usesDataSource = YES;
    comboBox.dataSource = self;
    comboBox.delegate = self;
    return view;
}
- (NSView *)setupTableUIWithPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.top.equalTo(preView.mas_bottom).offset(-5);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithLabelString:@"渠道列表" forView:view];
    NSButton *button = [NSButton buttonWithTitle:@"清除列表" target:self action:@selector(buttonAction:)];
    button.tag = ZCMainUIType_platformTable;
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
        make.top.equalTo(customLabel.mas_bottom).offset(5);
        make.left.equalTo(customLabel);
        make.width.mas_equalTo(235);
        make.height.mas_equalTo(200);
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
    tableView.dataSource = self;
    tableView.delegate = self;

    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(tableContainerView);
    }];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.bottom.equalTo(tableContainerView);
    }];
    
    self.platformTableView_ = tableView;
    self.cleanPlatformButton_ = button;
    return view;
}
- (NSView *)setupTextViewUIWithPreView:(NSView *)preView withRightView:(NSView *)rightView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(preView.mas_right);
        make.right.equalTo(rightView.mas_left).offset(-20);
        make.top.equalTo(preView);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithLabelString:@"已选择渠道" forView:view];
    
    NSScrollView *textContainerView = [[NSScrollView alloc] init];
    [textContainerView setDrawsBackground:NO];//不画背景（背景默认画成白色）
    [textContainerView setHasVerticalScroller:YES];//有垂直滚动条
    //[_textContainerView setHasHorizontalScroller:YES];//有水平滚动条
//    textContainerView.autohidesScrollers = YES;//自动隐藏滚动条（滚动的时候出现）
    [view addSubview:textContainerView];
    [textContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(customLabel.mas_bottom).offset(5);
        make.left.equalTo(customLabel);
        make.width.mas_greaterThanOrEqualTo(255);
        make.height.mas_equalTo(200);
    }];
    
    NSTextView *textView = [[NSTextView alloc] init];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [textView setEditable:NO];
    [view addSubview:textView];
    [textContainerView setDocumentView:textView];
    [textView sizeToFit];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(textContainerView);
    }];
    
    [view mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.bottom.equalTo(textContainerView);
    }];
    
    self.showSelectedPlatformField_ = textView;
    return view;
}
- (NSView *)setupLogViewUIWithPreView:(NSView *)preView {
    NSView *view = [[NSView alloc] init];
    [self addSubview:view];
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(preView);
    }];
    
    NSTextField *customLabel = [self setupTitleUIWithLabelString:@"输出日志" forView:view];
    
    NSScrollView *textContainerView = [[NSScrollView alloc] init];
    [textContainerView setDrawsBackground:NO];//不画背景（背景默认画成白色）
    [textContainerView setHasVerticalScroller:YES];//有垂直滚动条
    //[_textContainerView setHasHorizontalScroller:YES];//有水平滚动条
//    textContainerView.autohidesScrollers = YES;//自动隐藏滚动条（滚动的时候出现）
    [view addSubview:textContainerView];
    [textContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(customLabel.mas_bottom).offset(5);
        make.left.equalTo(customLabel);
        make.right.equalTo(view).offset(-20);
        make.height.mas_greaterThanOrEqualTo(120);
    }];
    
    NSTextView *textView = [[NSTextView alloc] init];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [textView setEditable:NO];
    [view addSubview:textView];
    [textContainerView setDocumentView:textView];
    [textView sizeToFit];
    NSView *lineView = [[NSView alloc] init];
    lineView.wantsLayer = YES;
    lineView.layer.borderColor = [NSColor systemGrayColor].CGColor;
    lineView.layer.borderWidth = 1;
    lineView.layer.cornerRadius = 5;
    [view addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(textContainerView);
    }];
    
    NSButton *button = [NSButton buttonWithTitle:@"清除日志" target:self action:@selector(buttonAction:)];
    button.tag = ZCMainUIType_LogView;
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
    
    self.logField_ = textView;
    self.cleanLogButton_ = button;
    return view;
}

- (void)setupInit {
    
}

#pragma mark - NSComboBoxDataSource, NSComboBoxDelegate
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    NSInteger count = 0;
    if ([comboBox isEqual:self.certificateComboBox_]) {
        count = self.certificatesArray.count;
    } else if ([comboBox isEqual:self.provisioningComboBox_]) {
        count = self.provisioningArray.count;
    }
    return count;
}
- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    id item = nil;
    if ([comboBox isEqual:self.certificateComboBox_]) {
        if (self.certificatesArray.count > index) {
            item = self.certificatesArray[index];
        }
    } else if ([comboBox isEqual:self.provisioningComboBox_]) {
        if (self.provisioningArray.count > index) {
            ZCProvisioningProfile *profile = self.provisioningArray[index];
            item = [NSString stringWithFormat:@"%@(%@) %@", profile.name, profile.bundleIdentifier, [[ZCDateFormatterUtil sharedFormatter] yyyyMMddHHmmssForDate:profile.creationDate]];
        }
    }
    return item;
}
- (void)setCertificatesArray:(NSArray *)certificatesArray {
    _certificatesArray = certificatesArray;
    [self.certificateComboBox_ reloadData];
    [self.certificateComboBox_ selectItemAtIndex:0];//默认选择第一个
}
- (void)setProvisioningArray:(NSArray *)provisioningArray {
    _provisioningArray = provisioningArray;
    [self.provisioningComboBox_ reloadData];
    [self.provisioningComboBox_ selectItemAtIndex:0];//默认选择第一个
}

#pragma mark - NSTableViewDataSource, NSTableViewDelegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger count = [[ZCFileHelper sharedInstance] platformArray].count;
    return count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PlatformRowView *rowView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
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

#pragma mark - LogField
- (void)addLog:(NSString *)log withColor:(NSColor *)color {
    NSLog(@"%@", log);
    dispatch_async(dispatch_get_main_queue(), ^{
        //添加时间
        NSString *dateString = [[ZCDateFormatterUtil sharedFormatter] yyyyMMddHHmmssSSSForDate:[NSDate date]];
        NSAttributedString *dateAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@]", dateString] attributes:@{NSForegroundColorAttributeName:[NSColor systemGrayColor]}];
        //添加log
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@\n", log] attributes:@{NSForegroundColorAttributeName:color}];
        
        [[self.logField_ textStorage] appendAttributedString:dateAttributedString];
        [[self.logField_ textStorage] appendAttributedString:logAttributedString];
        [self.logField_ scrollRangeToVisible:NSMakeRange([self.logField_ string].length, 0)];
        
    });
}
#pragma mark - showSelectedPlatformField
- (void)showSelectedPlatform:(NSString *)platforms {
    showSelectedPlatformFieldString = platforms;
        
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", platforms] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self.showSelectedPlatformField_ textStorage] setAttributedString:logAttributedString];
        [self.showSelectedPlatformField_ scrollRangeToVisible:NSMakeRange([self.showSelectedPlatformField_ string].length, 0)];
        
    });
}
- (void)showResigningPlatform:(NSString *)logString {
        
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", self->showSelectedPlatformFieldString, logString] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self.showSelectedPlatformField_ textStorage] setAttributedString:logAttributedString];
        [self.showSelectedPlatformField_ scrollRangeToVisible:NSMakeRange([self.showSelectedPlatformField_ string].length, 0)];
        
    });
}

- (void)enableControls {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ipaPathField_ setEnabled:YES];
        [self.browseIpaPathButton_ setEnabled:YES];
        [self.appIconPathField_ setEnabled:YES];
        [self.browseAppIconPathButton_ setEnabled:YES];
        [self.launchImagePathField_ setEnabled:YES];
        [self.browseLaunchImagePathButton_ setEnabled:YES];
        [self.certificateComboBox_ setEnabled:YES];
        [self.provisioningComboBox_ setEnabled:YES];
        [self.appNameField_ setEnabled:YES];
        [self.ipaSavePathField_ setEnabled:YES];
        [self.browseIpaSavePathButton_ setEnabled:YES];
        [self.radioButton_ setEnabled:YES];
        [self.bundleIDButton_ setEnabled:YES];
        [self.bundleIdField_ setEnabled:YES];
        [self.cleanLogButton_ setEnabled:YES];
        [self.cleanPlatformButton_ setEnabled:YES];
        [self.ipaResignButton_ setEnabled:YES];
        [self.platformSignButton_ setEnabled:YES];
        self->tableDisenable = NO;
        [[[ZCFileHelper sharedInstance] platformArray] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ZCPlatformDataJsonModel *model = (ZCPlatformDataJsonModel *)obj;
            model.isDisenable = NO;
        }];
        [self.platformTableView_ reloadData];
    });
}

- (void)disenableControls {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ipaPathField_ setEnabled:NO];
        [self.browseIpaPathButton_ setEnabled:NO];
        [self.appIconPathField_ setEnabled:NO];
        [self.browseAppIconPathButton_ setEnabled:NO];
        [self.launchImagePathField_ setEnabled:NO];
        [self.browseLaunchImagePathButton_ setEnabled:NO];
        [self.certificateComboBox_ setEnabled:NO];
        [self.provisioningComboBox_ setEnabled:NO];
        [self.appNameField_ setEnabled:NO];
        [self.ipaSavePathField_ setEnabled:NO];
        [self.browseIpaSavePathButton_ setEnabled:NO];
        [self.radioButton_ setEnabled:NO];
        [self.bundleIDButton_ setEnabled:NO];
        [self.bundleIdField_ setEnabled:NO];
        [self.cleanLogButton_ setEnabled:NO];
        [self.cleanPlatformButton_ setEnabled:NO];
        [self.ipaResignButton_ setEnabled:NO];
        [self.platformSignButton_ setEnabled:NO];
        self->tableDisenable = YES;
        [[[ZCFileHelper sharedInstance] platformArray] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ZCPlatformDataJsonModel *model = (ZCPlatformDataJsonModel *)obj;
            model.isDisenable = YES;
        }];
        [self.platformTableView_ reloadData];
    });
}


#pragma mark - Click
- (void)buttonAction:(NSButton *)button {
    if (self.delegate && [self.delegate respondsToSelector:@selector(viewButtonClick:)]) {
        [self.delegate viewButtonClick:button.tag];
    }
}


@end
