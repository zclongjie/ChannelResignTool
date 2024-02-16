//
//  ViewController.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/19.
//

#import "ViewController.h"
#import "ZCFileHelper.h"
#import "ZCDateFormatterUtil.h"
#import "ZCProvisioningProfile.h"
#import "ZCAppPackageHandler.h"
#import "PlatformRowView.h"

#import "ZCMainView.h"
#import "Masonry.h"

@interface ViewController ()<NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate, PlatformRowViewDelegate>

@property (weak) IBOutlet NSTextField *ipaPathField;
@property (weak) IBOutlet NSButton *browseIpaPathButton;
@property (weak) IBOutlet NSTextField *appIconPathField;
@property (weak) IBOutlet NSButton *browseAppIconPathButton;
@property (weak) IBOutlet NSTextField *launchImagePathField;
@property (weak) IBOutlet NSButton *browseLaunchImagePathButton;
@property (weak) IBOutlet NSComboBox *certificateComboBox;
@property (weak) IBOutlet NSComboBox *provisioningComboBox;
@property (weak) IBOutlet NSTextField *appNameField;
@property (weak) IBOutlet NSTextField *ipaSavePathField;
@property (weak) IBOutlet NSButton *browseIpaSavePathButton;
@property (weak) IBOutlet NSButton *radioButton;
@property (weak) IBOutlet NSButton *bundleIDButton;
@property (weak) IBOutlet NSTextField *bundleIdField;
@property (weak) IBOutlet NSButton *cleanLogButton;
@property (weak) IBOutlet NSButton *cleanPlatformButton;
@property (weak) IBOutlet NSButton *cleanAllButton;
@property (weak) IBOutlet NSButton *ipaResignButton;
@property (weak) IBOutlet NSButton *platformSignButton;
@property (unsafe_unretained) IBOutlet NSTextView *logField;
@property (weak) IBOutlet NSTableView *platformTableView;
@property (unsafe_unretained) IBOutlet NSTextView *showSelectedPlatformField;


@property (nonatomic, strong) ZCAppPackageHandler *package;

@property (nonatomic, strong) ZCMainView *mainView;


@end

@implementation ViewController {
    BOOL useMobileprovisionBundleID;
    
    NSArray *certificatesArray;
    NSArray *provisioningArray;
    
    NSFileManager *manager;
    
    NSString *showSelectedPlatformFieldString;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    manager = [NSFileManager defaultManager];

    NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PlatformRowView" bundle:nil];
    [self.platformTableView registerNib:nib forIdentifier:@"PlatformRowView"];
    
    //app文件
    [[ZCFileHelper sharedInstance] appSpaceError:^(NSString * _Nonnull error) {
        
    } success:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.platformTableView reloadData];
            
            [self.mainView tableReload];
        });
        
    }];
    
    
    ZCMainView *mainView = [[ZCMainView alloc] init];
    [self.view addSubview:mainView];
    [mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    self.mainView = mainView;
    
    NSArray *lackSupportUtility = [[ZCFileHelper sharedInstance] lackSupportUtility];
    if (lackSupportUtility.count == 0) {
        //获取本机证书
        [self getCertificates];
        //获取描述文件
        [self getProvisioningProfiles];
    } else {
        for (NSString *path in lackSupportUtility) {
            [self addLog:[NSString stringWithFormat:@"此命名缺少%@的支持", path] withColor:[NSColor systemRedColor]];
        }
    }
    
    [self.ipaPathField becomeFirstResponder];//让ipaPath为第一响应
    
    
    
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    [self clearall];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - Action

- (IBAction)browseIpaPathButtonAction:(id)sender {
    [self addLog:@"浏览ipa文件路径" withColor:[NSColor labelColor]];
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowsOtherFileTypes:NO];
    [openPanel setAllowedFileTypes:@[@"ipa", @"app"]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
        self.ipaPathField.stringValue = fileNameOpened;
        [self addLog:[NSString stringWithFormat:@"原始包文件:%@", fileNameOpened] withColor:[NSColor labelColor]];
    }
}
- (IBAction)browseAppIconPathButtonAction:(id)sender {
    [self addLog:@"浏览AppIcon文件路径" withColor:[NSColor labelColor]];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowsOtherFileTypes:NO];
    [openPanel setAllowedFileTypes:@[@"png"]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
        self.appIconPathField.stringValue = fileNameOpened;
        [self addLog:[NSString stringWithFormat:@"appIcon文件:%@", fileNameOpened] withColor:[NSColor labelColor]];
        
        
    }
    
    
}
- (IBAction)browseLaunchImagepathButtonAction:(id)sender {
    [self addLog:@"浏览LaunchImage文件路径" withColor:[NSColor labelColor]];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowsOtherFileTypes:NO];
    [openPanel setAllowedFileTypes:@[@"png"]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
        self.launchImagePathField.stringValue = fileNameOpened;
        [self addLog:[NSString stringWithFormat:@"LaunchImage文件:%@", fileNameOpened] withColor:[NSColor labelColor]];
    }
}


- (IBAction)browseIpaSavePathButtonAction:(id)sender {
    [self addLog:@"浏览ipa文件保存路径" withColor:[NSColor labelColor]];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowsOtherFileTypes:NO];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
        self.ipaSavePathField.stringValue = fileNameOpened;
        [self addLog:[NSString stringWithFormat:@"选择签名保存包目录:%@", fileNameOpened] withColor:[NSColor labelColor]];
    }
}
- (IBAction)radioButtonAction:(NSButton *)sender {
    if (sender.tag == 100 && sender.state == NSControlStateValueOn) {
        [self addLog:@"修改BundleID, 默认使用App中BundleID" withColor:[NSColor labelColor]];
        useMobileprovisionBundleID = NO;
    } else if (sender.tag == 101 && sender.state == NSControlStateValueOn) {
        [self addLog:@"使用mobileprovision中的BundleID" withColor:[NSColor labelColor]];
        useMobileprovisionBundleID = YES;
    }
}
- (IBAction)cleanButtonAction:(NSButton *)sender {
    if (sender.tag == 200) {
//        [self addLog:@"清除已选渠道" withColor:[NSColor labelColor]];
        [[[ZCFileHelper sharedInstance] platformArray] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ZCPlatformDataJsonModel *model = (ZCPlatformDataJsonModel *)obj;
            model.isSelect = NO;
        }];
        [self.platformTableView reloadData];
        [self showSelectPlatformView:@[].mutableCopy];
    } else if (sender.tag == 201) {
        [self addLog:@"清除全部" withColor:[NSColor labelColor]];
        [self clearall];
    } else if (sender.tag == 202) {
        [self addLog:@"清除日志" withColor:[NSColor labelColor]];
        self.logField.string = @"";
    }
}
- (IBAction)ipaResignAction:(id)sender {
    
    if (![self->manager fileExistsAtPath:self.ipaPathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"请选择ipa或app文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.certificateComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"请选择签名证书"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.provisioningComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"请选择描述文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if (![self->manager fileExistsAtPath:self.ipaSavePathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"请选择ipa文件生成目录"] withColor:[NSColor systemRedColor]];
        return;
    }
    [self addLog:@"-----------------------" withColor:[NSColor labelColor]];
    [self addLog:@"解压..." withColor:[NSColor systemGreenColor]];
    self.package = [[ZCAppPackageHandler alloc] initWithPackagePath:self.ipaPathField.stringValue];
    [self addLog:[NSString stringWithFormat:@"文件解压到:%@", self.package.temp_workPath] withColor:[NSColor systemGreenColor]];
    [self disenableControls];
    
    [self.package unzipIpaLog:^(BlockType type, NSString * _Nonnull logString) {
        [self addLog:logString withColor:[NSColor labelColor]];
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        [self enableControls];
        [self addLog:errorString withColor:[NSColor systemRedColor]];
    } success:^(BlockType type, id  _Nonnull message) {
        [self showIpaInfo];
        [self addLog:message withColor:[NSColor systemGreenColor]];
        
        ZCProvisioningProfile *provisioningProfile = [self->provisioningArray objectAtIndex:self.provisioningComboBox.indexOfSelectedItem];
        
        NSString *bundleIdentifier = @"";
        if (self->useMobileprovisionBundleID) {
            bundleIdentifier = provisioningProfile.bundleIdentifier;
        } else {
            if ([self.bundleIdField.stringValue length] == 0) {
                bundleIdentifier = self.package.bundleID;
            } else {
                bundleIdentifier = self.bundleIdField.stringValue;
            }
        }
        NSString *displayName = @"";
        if ([self.appNameField.stringValue length] == 0) {
            displayName = self.package.bundleDisplayName;
        } else {
            displayName = self.appNameField.stringValue;
        }
        [self.package removeCodeSignatureDirectory];

        [self addLog:@"开始签名" withColor:[NSColor systemGreenColor]];
        //开始签名
        [self.package resignWithProvisioningProfile:provisioningProfile certificateName:[self->certificatesArray objectAtIndex:self.certificateComboBox.indexOfSelectedItem] bundleIdentifier:provisioningProfile.bundleIdentifier displayName:displayName targetPath:self.ipaSavePathField.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
            [self addLog:logString withColor:[NSColor labelColor]];
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            [self addLog:errorString withColor:[NSColor systemRedColor]];
        } success:^(BlockType type, id  _Nonnull message) {
            [self addLog:message withColor:[NSColor systemGreenColor]];

            if (type == BlockType_PlatformAllEnd) {
                [self enableControls];
                //打包完成移除解压文件
                [self->manager removeItemAtPath:self.package.temp_workPath error:nil];
                [self addLog:@"-----------------------" withColor:[NSColor labelColor]];
            }

        }];
    }];
    
}

- (IBAction)platformSignAction:(id)sender {
    if (![self->manager fileExistsAtPath:self.ipaPathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"请选择ipa或app文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.certificateComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"请选择签名证书"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.provisioningComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"请选择描述文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if (![self->manager fileExistsAtPath:self.ipaSavePathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"请选择ipa文件生成目录"] withColor:[NSColor systemRedColor]];
        return;
    }
    
    if (![self->manager fileExistsAtPath:self.appIconPathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"请选择AppIcon文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    
    NSMutableArray *selectPlatforArray = @[].mutableCopy;
    [[[ZCFileHelper sharedInstance] platformArray] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        ZCPlatformDataJsonModel *model = (ZCPlatformDataJsonModel *)obj;
        if (model.isSelect) {
            [selectPlatforArray addObject:model];
        }
    }];
    if (selectPlatforArray.count == 0) {
        [self addLog:[NSString stringWithFormat:@"请选择渠道"] withColor:[NSColor systemRedColor]];
        return;
    }
    
    [self disenableControls];
    [self addLog:@"-----------------------" withColor:[NSColor labelColor]];
    NSString *launchImagePath = nil;
    if ([self->manager fileExistsAtPath:self.launchImagePathField.stringValue]) {
        launchImagePath = self.launchImagePathField.stringValue;
    }
    self.package = [[ZCAppPackageHandler alloc] initWithPackagePath:self.ipaPathField.stringValue];
    [self addLog:[NSString stringWithFormat:@"文件解压到:%@", self.package.temp_workPath] withColor:[NSColor systemGreenColor]];
    
    [self.package unzipIpaLog:^(BlockType type, NSString * _Nonnull logString) {
        [self addLog:logString withColor:[NSColor labelColor]];
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        [self enableControls];
        [self addLog:errorString withColor:[NSColor systemRedColor]];
    } success:^(BlockType type, id  _Nonnull message) {
        [self addLog:message withColor:[NSColor systemGreenColor]];
        [self.package removeCodeSignatureDirectory];

        [self addLog:@"开始渠道打包" withColor:[NSColor systemGreenColor]];
        ZCProvisioningProfile *provisioningProfile = [self->provisioningArray objectAtIndex:self.provisioningComboBox.indexOfSelectedItem];
        //开始签名
        [self.package platformbuildresignWithProvisioningProfile:provisioningProfile certificateName:[self->certificatesArray objectAtIndex:self.certificateComboBox.indexOfSelectedItem] platformModels:selectPlatforArray appIconPath:self.appIconPathField.stringValue launchImagePath:launchImagePath targetPath:self.ipaSavePathField.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
            [self addLog:logString withColor:[NSColor labelColor]];
            if (type == BlockType_PlatformShow) {
                [self showResigningPlatform:[NSString stringWithFormat:@"正在打包：%@", logString]];
            }
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            [self addLog:errorString withColor:[NSColor systemRedColor]];
        } success:^(BlockType type, id  _Nonnull message) {
            [self addLog:message withColor:[NSColor systemGreenColor]];
            
            if (type == BlockType_PlatformAllEnd) {
                [self enableControls];
                [self showResigningPlatform:message];
            }
        }];
    }];
}


#pragma mark - NSComboBoxDataSource, NSComboBoxDelegate
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    NSInteger count = 0;
    if ([comboBox isEqual:self.certificateComboBox]) {
        count = certificatesArray.count;
    } else if ([comboBox isEqual:self.provisioningComboBox]) {
        count = provisioningArray.count;
    }
    return count;
}
- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    id item = nil;
    if ([comboBox isEqual:self.certificateComboBox]) {
        item = certificatesArray[index];
    } else if ([comboBox isEqual:self.provisioningComboBox]) {
        ZCProvisioningProfile *profile = provisioningArray[index];
        item = [NSString stringWithFormat:@"%@(%@) %@", profile.name, profile.bundleIdentifier, [[ZCDateFormatterUtil sharedFormatter] yyyyMMddHHmmssForDate:profile.creationDate]];
    }
    return item;
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
        rowView.identifier = @"PlatformRowView";
    }
    rowView.delegate = self;
    ZCPlatformDataJsonModel *model = [[ZCFileHelper sharedInstance] platformArray][row];
    rowView.model = model;
    return rowView;
}
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

#pragma mark -
- (void)getCertificates {
    [[ZCFileHelper sharedInstance] getCertificatesLog:^(NSString * _Nonnull log) {
        [self addLog:log withColor:[NSColor labelColor]];
    } error:^(NSString * _Nonnull error) {
        [self addLog:error withColor:[NSColor systemRedColor]];
    } success:^(NSArray * _Nonnull certificateNames) {
        self->certificatesArray = certificateNames;
        self.mainView.certificatesArray = certificateNames;
        [self.certificateComboBox reloadData];
        [self.certificateComboBox selectItemAtIndex:0];//默认选择第一个
    }];
}

#pragma mark -
- (void)getProvisioningProfiles {
    provisioningArray = [[ZCFileHelper sharedInstance] getProvisioningProfiles];
    self.mainView.provisioningArray = provisioningArray;
    [self.provisioningComboBox reloadData];
    [self.provisioningComboBox selectItemAtIndex:0];//默认选择第一个
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
        
        [[self.logField textStorage] appendAttributedString:dateAttributedString];
        [[self.logField textStorage] appendAttributedString:logAttributedString];
        [self.logField scrollRangeToVisible:NSMakeRange([self.logField string].length, 0)];
        
    });
}
#pragma mark - showSelectedPlatformField
- (void)showSelectedPlatform:(NSString *)platforms {
    showSelectedPlatformFieldString = platforms;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", platforms] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self.showSelectedPlatformField textStorage] setAttributedString:logAttributedString];
        [self.showSelectedPlatformField scrollRangeToVisible:NSMakeRange([self.showSelectedPlatformField string].length, 0)];
        
    });
}
- (void)showResigningPlatform:(NSString *)logString {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", self->showSelectedPlatformFieldString, logString] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self.showSelectedPlatformField textStorage] setAttributedString:logAttributedString];
        [self.showSelectedPlatformField scrollRangeToVisible:NSMakeRange([self.showSelectedPlatformField string].length, 0)];
        
    });
}

#pragma mark - UI

- (void)enableControls {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ipaPathField setEnabled:YES];
        [self.browseIpaPathButton setEnabled:YES];
        [self.appIconPathField setEnabled:YES];
        [self.browseAppIconPathButton setEnabled:YES];
        [self.launchImagePathField setEnabled:YES];
        [self.browseLaunchImagePathButton setEnabled:YES];
        [self.certificateComboBox setEnabled:YES];
        [self.provisioningComboBox setEnabled:YES];
        [self.appNameField setEnabled:YES];
        [self.ipaSavePathField setEnabled:YES];
        [self.browseIpaSavePathButton setEnabled:YES];
        [self.radioButton setEnabled:YES];
        [self.bundleIDButton setEnabled:YES];
        [self.bundleIdField setEnabled:YES];
        [self.cleanLogButton setEnabled:YES];
        [self.cleanPlatformButton setEnabled:YES];
        [self.cleanAllButton setEnabled:YES];
        [self.ipaResignButton setEnabled:YES];
        [self.platformSignButton setEnabled:YES];
        [self.platformTableView setEnabled:YES];
    });
    
}

- (void)disenableControls {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ipaPathField setEnabled:NO];
        [self.browseIpaPathButton setEnabled:NO];
        [self.appIconPathField setEnabled:NO];
        [self.browseAppIconPathButton setEnabled:NO];
        [self.launchImagePathField setEnabled:NO];
        [self.browseLaunchImagePathButton setEnabled:NO];
        [self.certificateComboBox setEnabled:NO];
        [self.provisioningComboBox setEnabled:NO];
        [self.appNameField setEnabled:NO];
        [self.ipaSavePathField setEnabled:NO];
        [self.browseIpaSavePathButton setEnabled:NO];
        [self.radioButton setEnabled:NO];
        [self.bundleIDButton setEnabled:NO];
        [self.bundleIdField setEnabled:NO];
        [self.cleanLogButton setEnabled:NO];
        [self.cleanPlatformButton setEnabled:NO];
        [self.cleanAllButton setEnabled:NO];
        [self.ipaResignButton setEnabled:NO];
        [self.platformSignButton setEnabled:NO];
        [self.platformTableView setEnabled:NO];
    });
    
}

- (void)clearall {
    self.ipaPathField.stringValue = @"";
    self.appIconPathField.stringValue = @"";
    self.launchImagePathField.stringValue = @"";
    self.ipaSavePathField.stringValue = @"";

    self.appNameField.stringValue = @"";
    self.bundleIdField.stringValue = @"";
    self.logField.string = @"";
    
//    [manager removeItemAtPath:[ZCFileHelper sharedInstance].GameTemp error:nil];
//    self.package = nil;
    
    NSButton *btn = [self.view viewWithTag:200];
    [self cleanButtonAction:btn];
}

- (void)showIpaInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bundleIdField.stringValue = self.package.bundleID;
    });
}

@end
