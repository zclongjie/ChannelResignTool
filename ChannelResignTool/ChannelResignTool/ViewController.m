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

@interface ViewController ()<NSComboBoxDataSource, NSComboBoxDelegate>

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

@property (nonatomic, strong) ZCAppPackageHandler *package;


@end

@implementation ViewController {
    NSArray *certificatesArray;
    NSArray *provisioningArray;
    
    NSFileManager *manager;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    manager = [NSFileManager defaultManager];
    NSArray *lackSupportUtility = [[ZCFileHelper sharedInstance] lackSupportUtility];
    if (lackSupportUtility.count == 0) {
        //获取本机证书
        [self getCertificates];
        //获取描述文件
        [self getProvisioningProfiles];
    } else {
        for (NSString *path in lackSupportUtility) {
            [self addLog:[NSString stringWithFormat:@"此命名缺少%@的支持", path] withColor:[NSColor redColor]];
        }
    }
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
    NSLog(@"浏览ipa文件路径");
    
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
        [self addLog:[NSString stringWithFormat:@"原始包文件:%@", fileNameOpened] withColor:[NSColor whiteColor]];
        
        //移除之前包的解压文件
        if (self.package.workPath) {
            [manager removeItemAtPath:[self.package.workPath stringByDeletingLastPathComponent] error:nil];
        }
        
        //设置新的解压文件
        self.package = [[ZCAppPackageHandler alloc] initWithPackagePath:fileNameOpened];
        [self unzipIpa];
    }
}
- (IBAction)browseIpaSavePathButtonAction:(id)sender {
    NSLog(@"浏览ipa文件保存路径");
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowsOtherFileTypes:NO];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *fileNameOpened = [[[openPanel URLs] objectAtIndex:0] path];
        self.ipaSavePathField.stringValue = fileNameOpened;
        [self addLog:[NSString stringWithFormat:@"生成包目录:%@", fileNameOpened] withColor:[NSColor whiteColor]];
        
        
        
    }
}
- (IBAction)radioButtonAction:(NSButton *)sender {
    NSInteger tag = sender.tag;
    if (tag == 1) {
        NSLog(@"使用pro证书中的BundleID");
    } else {
        NSLog(@"修改BundleID, 默认使用App中BundleID");
    }
}
- (IBAction)cleanButton:(id)sender {
    NSLog(@"清除已选项");
    [self clearall];
}
- (IBAction)resignButton:(id)sender {
    NSLog(@"开始签名");
    
    if (![manager fileExistsAtPath:self.ipaPathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"未指定ipa或app文件"] withColor:[NSColor redColor]];
        return;
    }
    if ([self.certificateComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"未选择签名证书"] withColor:[NSColor redColor]];
        return;
    }
    if ([self.provisioningComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"未选择描述文件"] withColor:[NSColor redColor]];
        return;
    }
    if (![manager fileExistsAtPath:self.ipaSavePathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"未指定ipa文件生成目录"] withColor:[NSColor redColor]];
        return;
    }
    [self disenableControls];
    [self.package removeCodeSignatureDirectory];
    
    ZCProvisioningProfile *provisioningProfile = [provisioningArray objectAtIndex:self.provisioningComboBox.indexOfSelectedItem];
    //开始签名
    [self.package resignWithProvisioningProfile:provisioningProfile certiticateName:[certificatesArray objectAtIndex:self.certificateComboBox.indexOfSelectedItem] bundleIdentifier:provisioningProfile.bundleIdentifier displayName:self.appNameField.stringValue targetPath:self.ipaSavePathField.stringValue log:^(NSString * _Nonnull logString) {
        [self addLog:logString withColor:[NSColor whiteColor]];
    } error:^(NSString * _Nonnull errorString) {
        [self enableControls];
        [self addLog:errorString withColor:[NSColor redColor]];
    } success:^(id  _Nonnull message) {
        [self enableControls];
        [self addLog:[NSString stringWithFormat:@"签名成功,文件保存在%@", self.ipaSavePathField.stringValue] withColor:[NSColor greenColor]];
    }];
}

#pragma mark - 解压ipa
- (void)unzipIpa {
    [self addLog:[NSString stringWithFormat:@"文件提取到:%@", self.package.workPath] withColor:[NSColor whiteColor]];
    [self disenableControls];
    
    [self.package unzipIpa:^{
        [self addLog:[NSString stringWithFormat:@"文件提取完成"] withColor:[NSColor whiteColor]];
        [self showIpaInfo];
        [self enableControls];
    } error:^(NSString * _Nonnull error) {
        [self enableControls];
        [self addLog:error withColor:[NSColor redColor]];
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
        item = [NSString stringWithFormat:@"%@(%@) %@", profile.name, profile.bundleIdentifier, [[ZCDateFormatterUtil sharedFormatter] timestampForDate:profile.creationDate]];
    }
    return item;
}

#pragma mark -
- (void)getCertificates {
    [[ZCFileHelper sharedInstance] getCertificatesSuccess:^(NSArray * _Nonnull certificateNames) {
        self->certificatesArray = certificateNames;
        [self.certificateComboBox reloadData];
    } error:^(NSString * _Nonnull error) {
        [self addLog:error withColor:[NSColor redColor]];
    }];
}

#pragma mark -
- (void)getProvisioningProfiles {
    provisioningArray = [[ZCFileHelper sharedInstance] getProvisioningProfiles];
    [self.provisioningComboBox reloadData];
}

#pragma mark - LogField
- (void)addLog:(NSString *)log withColor:(NSColor *)color {
    dispatch_async(dispatch_get_main_queue(), ^{
        //添加时间
        NSString *dateString = [[ZCDateFormatterUtil sharedFormatter] MMddHHmmsssSSSForDate:[NSDate date]];
        NSAttributedString *dateAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@]", dateString] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}];
        //添加log
        NSAttributedString *logAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@\n", log] attributes:@{NSForegroundColorAttributeName:color}];
        
        [[self.logField textStorage] appendAttributedString:dateAttributedString];
        [[self.logField textStorage] appendAttributedString:logAttributedString];
        [self.logField scrollRangeToVisible:NSMakeRange([self.logField string].length, 0)];
        
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
    
    [manager removeItemAtPath:TEMP_PATH error:nil];
    self.package = nil;
}

- (void)showIpaInfo {
    self.appNameField.stringValue = self.package.bundleDisplayName;
    self.bundleIdField.stringValue = self.package.bundleID;
}

@end