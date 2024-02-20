//
//  ViewController.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/19.
//

#import "ViewController.h"
#import "ZCFileHelper.h"
#import "ZCProvisioningProfile.h"
#import "ZCAppPackageHander.h"
//#import "ZCAppPackageHandler.h"
//#import "ZCAppPlatformPackageHandler.h"

#import "ZCMainView.h"
#import "Masonry.h"

@interface ViewController ()<ZCMainViewDelegate>

@property (nonatomic, strong) ZCAppPackageHander *package;

@property (nonatomic, strong) ZCMainView *mainView;

@end

@implementation ViewController {
    BOOL useMobileprovisionBundleID;
        
    NSFileManager *manager;
    
    NSString *showSelectedPlatformFieldString;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    manager = [NSFileManager defaultManager];
    
    ZCMainView *mainView = [[ZCMainView alloc] init];
    mainView.delegate = self;
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
            [self.mainView addLog:[NSString stringWithFormat:@"此命名缺少%@的支持", path] withColor:[NSColor systemRedColor]];
        }
    }
    
    //app文件
    [[ZCFileHelper sharedInstance] appSpaceError:^(NSString * _Nonnull error) {
        
    } success:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mainView.platformTableView_ reloadData];
        });
        
    }];
    
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark -
- (void)getCertificates {
    [[ZCFileHelper sharedInstance] getCertificatesLog:^(NSString * _Nonnull log) {
        [self.mainView addLog:log withColor:[NSColor labelColor]];
    } error:^(NSString * _Nonnull error) {
        [self.mainView addLog:error withColor:[NSColor systemRedColor]];
    } success:^(NSArray * _Nonnull certificateNames) {
        self.mainView.certificatesArray = certificateNames;
    }];
}

#pragma mark -
- (void)getProvisioningProfiles {
    self.mainView.provisioningArray = [[ZCFileHelper sharedInstance] getProvisioningProfiles];;
}

#pragma mark - UI
- (void)clearall {
    self.mainView.ipaPathField_.stringValue = @"";
    self.mainView.appIconPathField_.stringValue = @"";
    self.mainView.launchImagePathField_.stringValue = @"";
    self.mainView.ipaSavePathField_.stringValue = @"";

    self.mainView.appNameField_.stringValue = @"";
    self.mainView.bundleIdField_.stringValue = @"";
    self.mainView.logField_.string = @"";
    
    [self viewButtonClick:ZCMainUIType_platformTable];
}

#pragma mark - ZCMianViewDelegate
- (void)viewButtonClick:(ZCMainUIType)uiType {
    NSLog(@"buttonTag - %ld", uiType);
    if (uiType == ZCMainUIType_ipaPathField) {
        [self.mainView addLog:@"浏览ipa文件路径" withColor:[NSColor labelColor]];
        
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setCanChooseFiles:YES];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setAllowsOtherFileTypes:NO];
        [openPanel setAllowedFileTypes:@[@"ipa", @"app"]];
        
        if ([openPanel runModal] == NSModalResponseOK) {
            
            //先移除之前的解压路径
            if ([self->manager fileExistsAtPath:self.package.temp_workPath]) {
                [self->manager removeItemAtPath:self.package.temp_workPath error:nil];
            }
            
            NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
            self.mainView.ipaPathField_.stringValue = fileNameOpened;
            [self.mainView addLog:[NSString stringWithFormat:@"原始包文件:%@", fileNameOpened] withColor:[NSColor labelColor]];
            
            //解压
            self.package = [[ZCAppPackageHander alloc] initWithPackagePath:self.mainView.ipaPathField_.stringValue];
            [self.mainView addLog:[NSString stringWithFormat:@"文件解压到:%@", self.package.temp_workPath] withColor:[NSColor systemGreenColor]];
            [self.mainView disenableControls];
            [self.package unzipIpaLog:^(BlockType type, NSString * _Nonnull logString) {
                [self.mainView addLog:logString withColor:[NSColor labelColor]];
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                [self.mainView enableControls];
                [self.mainView addLog:errorString withColor:[NSColor systemRedColor]];
            } success:^(BlockType type, id  _Nonnull message) {
                [self.mainView enableControls];
                [self.mainView addLog:message withColor:[NSColor systemGreenColor]];
                if (self.package.bundleIdentifier) {
                    self.mainView.bundleIdField_.stringValue = self.package.bundleIdentifier;
                }
                if (self.package.bundleDisplayName) {
                    self.mainView.appNameField_.stringValue = self.package.bundleDisplayName;
                }
                
            }];
        }
    } else if (uiType == ZCMainUIType_ipaSavePathField) {
        [self.mainView addLog:@"浏览ipa文件保存路径" withColor:[NSColor labelColor]];
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setCanChooseFiles:NO];
        [openPanel setCanChooseDirectories:YES];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setAllowsOtherFileTypes:NO];
        [openPanel setCanCreateDirectories:YES];
        
        if ([openPanel runModal] == NSModalResponseOK) {
            NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
            self.mainView.ipaSavePathField_.stringValue = fileNameOpened;
            [self.mainView addLog:[NSString stringWithFormat:@"选择签名保存包目录:%@", fileNameOpened] withColor:[NSColor labelColor]];
        }
    } else if (uiType == ZCMainUIType_changeBundleID) {
        [self.mainView addLog:@"修改BundleID, 默认使用App中BundleID" withColor:[NSColor labelColor]];
        useMobileprovisionBundleID = NO;
    } else if (uiType == ZCMainUIType_proBundleID) {
        [self.mainView addLog:@"使用mobileprovision中的BundleID" withColor:[NSColor labelColor]];
        useMobileprovisionBundleID = YES;
    } else if (uiType == ZCMainUIType_chongqian) {
        [self mubaoToIpa];
    } else if (uiType == ZCMainUIType_appIconPath) {
        [self.mainView addLog:@"浏览AppIcon文件路径" withColor:[NSColor labelColor]];
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setCanChooseFiles:YES];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setAllowsOtherFileTypes:NO];
        [openPanel setAllowedFileTypes:@[@"png"]];
        
        if ([openPanel runModal] == NSModalResponseOK) {
            NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
            self.mainView.appIconPathField_.stringValue = fileNameOpened;
            [self.mainView addLog:[NSString stringWithFormat:@"appIcon文件:%@", fileNameOpened] withColor:[NSColor labelColor]];
        }
    } else if (uiType == ZCMainUIType_launchImagePath) {
        [self.mainView addLog:@"浏览LaunchImage文件路径" withColor:[NSColor labelColor]];
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setCanChooseFiles:YES];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setAllowsOtherFileTypes:NO];
        [openPanel setAllowedFileTypes:@[@"png"]];
        
        if ([openPanel runModal] == NSModalResponseOK) {
            NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
            self.mainView.launchImagePathField_.stringValue = fileNameOpened;
            [self.mainView addLog:[NSString stringWithFormat:@"LaunchImage文件:%@", fileNameOpened] withColor:[NSColor labelColor]];
        }
    } else if (uiType == ZCMainUIType_platformTable) {
        [[[ZCFileHelper sharedInstance] platformArray] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ZCPlatformDataJsonModel *model = (ZCPlatformDataJsonModel *)obj;
            model.isSelect = NO;
        }];
        [self.mainView.platformTableView_ reloadData];
        [self.mainView showSelectPlatformView:@[].mutableCopy];
    } else if (uiType == ZCMainUIType_platformResign) {
        [self platformToIpa];
    } else if (uiType == ZCMainUIType_LogView) {
        [self.mainView addLog:@"清除日志" withColor:[NSColor labelColor]];
        self.mainView.logField_.string = @"";
    }
}

#pragma mark - 母包重签
- (void)mubaoToIpa {
    if (![self->manager fileExistsAtPath:self.mainView.ipaPathField_.stringValue]) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择ipa或app文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.mainView.certificateComboBox_ indexOfSelectedItem] == -1) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择签名证书"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.mainView.provisioningComboBox_ indexOfSelectedItem] == -1) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择描述文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if (![self->manager fileExistsAtPath:self.mainView.ipaSavePathField_.stringValue]) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择ipa文件生成目录"] withColor:[NSColor systemRedColor]];
        return;
    }
    [self.mainView addLog:@"-----------------------" withColor:[NSColor systemBlueColor]];
    [self.mainView disenableControls];
    
    ZCProvisioningProfile *provisioningProfile = [self.mainView.provisioningArray objectAtIndex:self.mainView.provisioningComboBox_.indexOfSelectedItem];

    [self.mainView addLog:@"开始母包签名" withColor:[NSColor systemGreenColor]];
    //开始签名
    [self.package resignWithProvisioningProfile:provisioningProfile certificateName:[self.mainView.certificatesArray objectAtIndex:self.mainView.certificateComboBox_.indexOfSelectedItem] useMobileprovisionBundleID:self->useMobileprovisionBundleID bundleIdField_str:self.mainView.bundleIdField_.stringValue appNameField_str:self.mainView.appNameField_.stringValue targetPath:self.mainView.ipaSavePathField_.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
        [self.mainView addLog:logString withColor:[NSColor labelColor]];
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        [self.mainView enableControls];
        [self.mainView addLog:errorString withColor:[NSColor systemRedColor]];
    } success:^(BlockType type, id  _Nonnull message) {
        [self.mainView addLog:message withColor:[NSColor systemGreenColor]];

        if (type == BlockType_PlatformAllEnd) {
            [self.mainView enableControls];
        }

    }];
}

#pragma mark - 渠道打包
- (void)platformToIpa {
    if (![self->manager fileExistsAtPath:self.mainView.ipaPathField_.stringValue]) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择ipa或app文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.mainView.certificateComboBox_ indexOfSelectedItem] == -1) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择签名证书"] withColor:[NSColor systemRedColor]];
        return;
    }
    if ([self.mainView.provisioningComboBox_ indexOfSelectedItem] == -1) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择描述文件"] withColor:[NSColor systemRedColor]];
        return;
    }
    if (![self->manager fileExistsAtPath:self.mainView.ipaSavePathField_.stringValue]) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择ipa文件生成目录"] withColor:[NSColor systemRedColor]];
        return;
    }
    
    if (![self->manager fileExistsAtPath:self.mainView.appIconPathField_.stringValue]) {
        [self.mainView addLog:[NSString stringWithFormat:@"请选择AppIcon文件"] withColor:[NSColor systemRedColor]];
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
        [self.mainView addLog:[NSString stringWithFormat:@"请选择渠道"] withColor:[NSColor systemRedColor]];
        return;
    }
    
    NSString *launchImagePath = nil;
    if ([self->manager fileExistsAtPath:self.mainView.launchImagePathField_.stringValue]) {
        launchImagePath = self.mainView.launchImagePathField_.stringValue;
    }
    
    [self.mainView disenableControls];
    [self.mainView addLog:@"-----------------------" withColor:[NSColor systemBlueColor]];
    ZCProvisioningProfile *provisioningProfile = [self.mainView.provisioningArray objectAtIndex:self.mainView.provisioningComboBox_.indexOfSelectedItem];
    
    [self.mainView addLog:@"开始渠道打包" withColor:[NSColor systemGreenColor]];

    //开始签名
    [self.package platformbuildresignWithProvisioningProfile:provisioningProfile certificateName:[self.mainView.certificatesArray objectAtIndex:self.mainView.certificateComboBox_.indexOfSelectedItem] platformModels:selectPlatforArray appIconPath:self.mainView.appIconPathField_.stringValue launchImagePath:launchImagePath targetPath:self.mainView.ipaSavePathField_.stringValue log:^(BlockType type, NSString * _Nonnull logString) {
        [self.mainView addLog:logString withColor:[NSColor labelColor]];
        if (type == BlockType_PlatformShow) {
            [self.mainView showResigningPlatform:[NSString stringWithFormat:@"正在打包：%@", logString]];
        }
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        [self.mainView addLog:errorString withColor:[NSColor systemRedColor]];
    } success:^(BlockType type, id  _Nonnull message) {
        [self.mainView addLog:message withColor:[NSColor systemGreenColor]];
        
        if (type == BlockType_PlatformAllEnd) {
            [self.mainView enableControls];
            [self.mainView showResigningPlatform:message];
        }
    }];
}

@end
