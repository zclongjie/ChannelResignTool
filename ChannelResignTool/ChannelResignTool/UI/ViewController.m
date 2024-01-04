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
@property (weak) IBOutlet NSTextField *bundleIdField;
@property (weak) IBOutlet NSButton *cleanButton;
@property (weak) IBOutlet NSButton *resignButton;
@property (unsafe_unretained) IBOutlet NSTextView *logField;

@property (weak) IBOutlet NSTableView *platformTableView;
@property (unsafe_unretained) IBOutlet NSTextView *showSelectedPlatformField;


@property (nonatomic, strong) ZCAppPackageHandler *package;


@end

@implementation ViewController {
    BOOL useMobileprovisionBundleID;
    
    NSArray *certificatesArray;
    NSArray *provisioningArray;
    NSMutableArray *tempPlatformArray;
    
    NSFileManager *manager;
    
    NSString *showSelectedPlatformFieldString;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    manager = [NSFileManager defaultManager];

    NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PlatformRowView" bundle:nil];
    [self.platformTableView registerNib:nib forIdentifier:@"PlatformRowView"];
    tempPlatformArray = @[].mutableCopy;
    
    ZCPlatformModel *model = [[ZCPlatformModel alloc] init];
    model.platformName = @"朋克";
    model.gameName = @"街机之三国战记";
    model.bundleIdentifier = @"com.jjsgios.punk";
    model.platformId = @"30241";
    model.alias = @"pengke";
    model.version = @"1.0.2";
    model.isLan = @"0";
    model.parameter = @{
        @"package": @"com.jjsgios.punk",
        @"appID": @"11654",
        @"appKey": @"a7832bbb02c086a061c75b8cfcaec4e7",
        @"clientID": @"11597",
        @"clientKey": @"ad619c4b10c8b23a300968ff3ca9b311"
    };
    model.isSelect = NO;
    [tempPlatformArray addObject:model];
    
    ZCPlatformModel *model2 = [[ZCPlatformModel alloc] init];
    model2.platformName = @"早游戏";
    model2.gameName = @"街机之三国战记";
    model2.bundleIdentifier = @"com.jjsgios.zaoyx";
    model2.platformId = @"208";
    model2.alias = @"zaoyouxi";
    model2.version = @"13.0.2";
    model2.isLan = @"0";
    model2.parameter = @{
        @"package": @"com.jjsgios.zaoyx",
        @"appID": @"141132",
        @"appKey": @"4d483faa7a65ef69a9f847300541f6c5",
        @"clientID": @"21199",
        @"clientKey": @"560dd236c91d04d67057dc86b68201d8"
    };
    model2.isSelect = NO;
    [tempPlatformArray addObject:model2];

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
    
    //app文件
    [[ZCFileHelper sharedInstance] appSpace];
    
    
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
- (IBAction)cleanButton:(NSButton *)sender {
    if (sender.tag == 200) {
//        [self addLog:@"清除已选渠道" withColor:[NSColor labelColor]];
        [tempPlatformArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ZCPlatformModel *model = (ZCPlatformModel *)obj;
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
- (IBAction)resignButton:(id)sender {
    
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
    
    BOOL platformResign = YES;
    
    if (platformResign) {
        
        if (![self->manager fileExistsAtPath:self.appIconPathField.stringValue]) {
            [self addLog:[NSString stringWithFormat:@"请选择AppIcon文件"] withColor:[NSColor systemRedColor]];
            return;
        }
        
        NSMutableArray *selectPlatforArray = @[].mutableCopy;
        [self->tempPlatformArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ZCPlatformModel *model = (ZCPlatformModel *)obj;
            if (model.isSelect) {
                [selectPlatforArray addObject:model];
            }
        }];
        if (selectPlatforArray.count == 0) {
            [self addLog:[NSString stringWithFormat:@"请选择渠道"] withColor:[NSColor systemRedColor]];
            return;
        }
        
        [self addLog:@"解压..." withColor:[NSColor systemGreenColor]];
        self.package = [[ZCAppPackageHandler alloc] initWithPackagePath:self.ipaPathField.stringValue];
        [self addLog:[NSString stringWithFormat:@"文件解压到:%@", self.package.workPath] withColor:[NSColor systemGreenColor]];
        [self disenableControls];
        
        [self.package unzipIpaLog:^(BlockType type, NSString * _Nonnull logString) {
            [self addLog:logString withColor:[NSColor labelColor]];
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            [self enableControls];
            [self addLog:errorString withColor:[NSColor systemRedColor]];
        } success:^(BlockType type, id  _Nonnull message) {
            [self addLog:message withColor:[NSColor systemGreenColor]];
            
            //生成AppIcon
            
            [self addLog:@"开始渠道打包" withColor:[NSColor systemGreenColor]];
            
            [self.package removeCodeSignatureDirectory];
            
            ZCProvisioningProfile *provisioningProfile = [self->provisioningArray objectAtIndex:self.provisioningComboBox.indexOfSelectedItem];
            //开始签名
            [self.package platformbuildresignWithProvisioningProfile:provisioningProfile certiticateName:[self->certificatesArray objectAtIndex:self.certificateComboBox.indexOfSelectedItem] platformModels:selectPlatforArray appIconPath:self.appIconPathField.stringValue targetPath:self.ipaSavePathField.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
                [self addLog:logString withColor:[NSColor labelColor]];
                if (type == BlockType_PlatformShow) {
                    [self showResigningPlatform:[NSString stringWithFormat:@"正在打包：%@", logString]];
                }
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                [self enableControls];
                [self addLog:errorString withColor:[NSColor systemRedColor]];
            } success:^(BlockType type, id  _Nonnull message) {
                [self enableControls];
                [self addLog:message withColor:[NSColor systemGreenColor]];
                if (type == BlockType_PlatformShow) {
                    [self showResigningPlatform:message];
                }
                if (type == BlockType_PlatformAllEnd) {
                    //打包完成移除解压文件
                    if (self.package.workPath) {
                        [self->manager removeItemAtPath:[self.package.workPath stringByDeletingLastPathComponent] error:nil];
                    }
                }
            }];
        }];
    } else {
        
        [self addLog:@"解压..." withColor:[NSColor systemGreenColor]];
        self.package = [[ZCAppPackageHandler alloc] initWithPackagePath:self.ipaPathField.stringValue];
        [self addLog:[NSString stringWithFormat:@"文件解压到:%@", self.package.workPath] withColor:[NSColor systemGreenColor]];
        [self disenableControls];
        
        [self.package unzipIpaLog:^(BlockType type, NSString * _Nonnull logString) {
            [self addLog:logString withColor:[NSColor labelColor]];
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            [self enableControls];
            [self addLog:errorString withColor:[NSColor systemRedColor]];
        } success:^(BlockType type, id  _Nonnull message) {
            [self showIpaInfo];
            [self addLog:message withColor:[NSColor systemGreenColor]];
            
            NSString *bundleIdentifier = @"";
            if (self->useMobileprovisionBundleID) {
                ZCProvisioningProfile *file = self->provisioningArray[self.provisioningComboBox.indexOfSelectedItem];
                bundleIdentifier = file.bundleIdentifier;
            } else {
                if ([self.bundleIdField.stringValue length] == 0) {
                    [self addLog:[NSString stringWithFormat:@"此App没有找到bundleID"] withColor:[NSColor systemRedColor]];
                    return;
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
            
            [self addLog:@"开始签名" withColor:[NSColor systemGreenColor]];
            
            [self.package removeCodeSignatureDirectory];
            
            ZCProvisioningProfile *provisioningProfile = [self->provisioningArray objectAtIndex:self.provisioningComboBox.indexOfSelectedItem];
            //开始签名
            [self.package resignWithProvisioningProfile:provisioningProfile certiticateName:[self->certificatesArray objectAtIndex:self.certificateComboBox.indexOfSelectedItem] bundleIdentifier:provisioningProfile.bundleIdentifier displayName:displayName targetPath:self.ipaSavePathField.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
                [self addLog:logString withColor:[NSColor labelColor]];
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                [self enableControls];
                [self addLog:errorString withColor:[NSColor systemRedColor]];
            } success:^(BlockType type, id  _Nonnull message) {
                [self enableControls];
                [self addLog:message withColor:[NSColor systemGreenColor]];
    
                if (type == BlockType_PlatformAllEnd) {
                    //打包完成移除解压文件
                    if (self.package.workPath) {
                        [self->manager removeItemAtPath:[self.package.workPath stringByDeletingLastPathComponent] error:nil];
                    }
                }
    
            }];
        }];
    }
    
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
    NSInteger count = tempPlatformArray.count;
    
    return count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PlatformRowView *rowView = [tableView makeViewWithIdentifier:@"PlatformRowView" owner:self];
    if (!rowView) {
        rowView = [[PlatformRowView alloc] init];
        rowView.identifier = @"PlatformRowView";
    }
    rowView.delegate = self;
    ZCPlatformModel *model = tempPlatformArray[row];
    rowView.model = model;
    return rowView;
}
- (void)platformRowViewButtonClick:(ZCPlatformModel *)selectModel {
    NSMutableArray *selectPlatformNameArray = @[].mutableCopy;
    [tempPlatformArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        ZCPlatformModel *model = (ZCPlatformModel *)obj;
        if (model.isSelect) {
            [selectPlatformNameArray addObject:model.platformName];
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
        [self.certificateComboBox reloadData];
        [self.certificateComboBox selectItemAtIndex:0];//默认选择第一个
    }];
}

#pragma mark -
- (void)getProvisioningProfiles {
    provisioningArray = [[ZCFileHelper sharedInstance] getProvisioningProfiles];
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
        [self.certificateComboBox setEnabled:YES];
        [self.provisioningComboBox setEnabled:YES];
        [self.appNameField setEnabled:YES];
        [self.ipaSavePathField setEnabled:YES];
        [self.browseIpaSavePathButton setEnabled:YES];
        [self.bundleIdField setEnabled:YES];
        [self.resignButton setEnabled:YES];
        [self.cleanButton setEnabled:YES];
        
    });
    
}

- (void)disenableControls {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ipaPathField setEnabled:NO];
        [self.browseIpaPathButton setEnabled:NO];
        [self.certificateComboBox setEnabled:NO];
        [self.provisioningComboBox setEnabled:NO];
        [self.appNameField setEnabled:NO];
        [self.ipaSavePathField setEnabled:NO];
        [self.browseIpaSavePathButton setEnabled:NO];
        [self.bundleIdField setEnabled:NO];
        [self.resignButton setEnabled:NO];
        [self.cleanButton setEnabled:NO];
        
    });
    
}

- (void)clearall {
    self.ipaPathField.stringValue = @"";
    self.appNameField.stringValue = @"";
    self.ipaSavePathField.stringValue = @"";
    self.bundleIdField.stringValue = @"";
    self.logField.string = @"";
    
    [manager removeItemAtPath:[CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"GameUnzip"] error:nil];
    self.package = nil;
    
    NSButton *btn = [self.view viewWithTag:200];
    [self cleanButton:btn];
}

- (void)showIpaInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bundleIdField.stringValue = self.package.bundleID;
        
    });
}

@end
