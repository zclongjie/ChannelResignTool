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

@interface ViewController ()<NSComboBoxDataSource, NSComboBoxDelegate, NSTableViewDataSource, NSTableViewDelegate, PlatformRowViewDelegate> {
    BOOL useMobileprovisionBundleID;
}

@property (weak) IBOutlet NSTextField *ipaPathField;
@property (weak) IBOutlet NSButton *browseIpaPathButton;
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
    NSArray *certificatesArray;
    NSArray *provisioningArray;
    NSMutableArray *tempPlatformArray;
    
    NSFileManager *manager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    manager = [NSFileManager defaultManager];

    NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PlatformRowView" bundle:nil];
    [self.platformTableView registerNib:nib forIdentifier:@"PlatformRowView"];
    tempPlatformArray = @[].mutableCopy;
    for (NSInteger i = 0; i < 50; i++) {
        PlatformRowViewModel *model = [[PlatformRowViewModel alloc] init];
        model.name = [NSString stringWithFormat:@"%ld", i];
        model.platformId = [NSString stringWithFormat:@"%ld", i];
        model.isSelect = NO;
        [tempPlatformArray addObject:model];
    }

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
    [self.view.window makeFirstResponder:nil];
    
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
        [self addLog:@"清除已选渠道" withColor:[NSColor labelColor]];
        [tempPlatformArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PlatformRowViewModel *model = (PlatformRowViewModel *)obj;
            model.isSelect = NO;
        }];
        [self.platformTableView reloadData];
        [self showSelectPlatformView:@[].mutableCopy];
    } else if (sender.tag == 201) {
        [self addLog:@"清除全部" withColor:[NSColor labelColor]];
        [self clearall];
    }
}
- (IBAction)resignButton:(id)sender {
    
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
        [self enableControls];
        [self addLog:message withColor:[NSColor systemGreenColor]];
        
        [self addLog:@"开始签名" withColor:[NSColor systemGreenColor]];
        
        if (![self->manager fileExistsAtPath:self.ipaPathField.stringValue]) {
            [self addLog:[NSString stringWithFormat:@"未指定ipa或app文件"] withColor:[NSColor systemRedColor]];
            return;
        }
        if ([self.certificateComboBox indexOfSelectedItem] == -1) {
            [self addLog:[NSString stringWithFormat:@"未选择签名证书"] withColor:[NSColor systemRedColor]];
            return;
        }
        if ([self.provisioningComboBox indexOfSelectedItem] == -1) {
            [self addLog:[NSString stringWithFormat:@"未选择描述文件"] withColor:[NSColor systemRedColor]];
            return;
        }
        if (![self->manager fileExistsAtPath:self.ipaSavePathField.stringValue]) {
            [self addLog:[NSString stringWithFormat:@"未指定ipa文件生成目录"] withColor:[NSColor systemRedColor]];
            return;
        }
        
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
        
        [self disenableControls];
        [self.package removeCodeSignatureDirectory];
        
        ZCProvisioningProfile *provisioningProfile = [self->provisioningArray objectAtIndex:self.provisioningComboBox.indexOfSelectedItem];
        //开始签名
        [self.package resignWithProvisioningProfile:provisioningProfile certiticateName:[self->certificatesArray objectAtIndex:self.certificateComboBox.indexOfSelectedItem] bundleIdentifier:provisioningProfile.bundleIdentifier displayName:self.appNameField.stringValue targetPath:self.ipaSavePathField.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
            [self addLog:logString withColor:[NSColor labelColor]];
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            [self enableControls];
            [self addLog:errorString withColor:[NSColor systemRedColor]];
        } success:^(BlockType type, id  _Nonnull message) {
            [self enableControls];
            [self addLog:message withColor:[NSColor systemGreenColor]];
            
            if (type == BlockType_ZipPackage) {
                [self addLog:[NSString stringWithFormat:@"【%@】完成签名", self.package.bundleDisplayName] withColor:[NSColor systemGreenColor]];
                //打包完成移除解压文件
                if (self.package.workPath) {
                    [self->manager removeItemAtPath:[self.package.workPath stringByDeletingLastPathComponent] error:nil];
                }
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
    PlatformRowViewModel *model = tempPlatformArray[row];
    rowView.model = model;
    return rowView;
}
- (void)platformRowViewButtonClick:(PlatformRowViewModel *)selectModel {
    NSMutableArray *selectPlatformNameArray = @[].mutableCopy;
    [tempPlatformArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PlatformRowViewModel *model = (PlatformRowViewModel *)obj;
        if (model.isSelect) {
            [selectPlatformNameArray addObject:model.name];
        }
    }];
    [self showSelectPlatformView:selectPlatformNameArray];
}
- (void)showSelectPlatformView:(NSMutableArray *)selectPlatformNameArray {
    if (selectPlatformNameArray.count) {
        NSString *platforms = [selectPlatformNameArray componentsJoinedByString:@"、"];
        [self showSelectedPlatform:[NSString stringWithFormat:@"已选择 %ld 个渠道：\n%@", selectPlatformNameArray.count, platforms]];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", platforms] attributes:@{NSForegroundColorAttributeName:[NSColor textColor], NSFontAttributeName:[NSFont systemFontOfSize:14]}];
        [[self.showSelectedPlatformField textStorage] setAttributedString:logAttributedString];
        [self.showSelectedPlatformField scrollRangeToVisible:NSMakeRange([self.showSelectedPlatformField string].length, 0)];
        
    });
}

#pragma mark - UI

- (void)enableControls {
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
}

- (void)disenableControls {
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
}

- (void)clearall {
    self.ipaPathField.stringValue = @"";
    self.appNameField.stringValue = @"";
    self.ipaSavePathField.stringValue = @"";
    self.bundleIdField.stringValue = @"";
    self.logField.string = @"";
    
    [manager removeItemAtPath:[CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"unzip"] error:nil];
    self.package = nil;
    
    NSButton *btn = [self.view viewWithTag:200];
    [self cleanButton:btn];
}

- (void)showIpaInfo {
    self.bundleIdField.stringValue = self.package.bundleID;
}

@end
