//
//  ZCFileHelper.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/22.
//

#import "ZCFileHelper.h"
#import "ZCProvisioningProfile.h"
#import "ZCRunLoop.h"
#import "ZCManuaQueue.h"
#import "ZCAppIconModel.h"

static const NSString *kMobileprovisionDirName = @"Library/MobileDevice/Provisioning Profiles";

@implementation ZCFileHelper {
    NSFileManager *manager;//全局文件管理
    NSArray *provisionExtensions;//配置文件扩展名
}

+ (instancetype)sharedInstance {
    static ZCFileHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ZCFileHelper alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        manager = [NSFileManager defaultManager];
        provisionExtensions = @[@"mobileprovision", @"provisionprofile"];
    }
    return self;
}

- (void)appSpace {
    
    NSString *DownSdk = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"DownSdk"];
    NSString *ChannelData = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"ChannelData"];
    NSString *PlatformUnzip = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"PlatformUnzip"];
    NSString *GameUnzip = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"GameUnzip"];
    //创建新目录
    if (![manager fileExistsAtPath:DownSdk]) {
        [manager createDirectoryAtPath:DownSdk withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![manager fileExistsAtPath:ChannelData]) {
        [manager createDirectoryAtPath:ChannelData withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![manager fileExistsAtPath:PlatformUnzip]) {
        [manager createDirectoryAtPath:PlatformUnzip withIntermediateDirectories:YES attributes:nil error:nil];
    } else {
        NSArray *contents = [self->manager contentsOfDirectoryAtPath:PlatformUnzip error:nil];
        for (NSString *file in contents) {
            NSString *filePath = [PlatformUnzip stringByAppendingPathComponent:file];
            [manager removeItemAtPath:filePath error:nil];
        }
    }
    if (![manager fileExistsAtPath:GameUnzip]) {
        [manager createDirectoryAtPath:GameUnzip withIntermediateDirectories:YES attributes:nil error:nil];
    } else {
        NSArray *contents = [self->manager contentsOfDirectoryAtPath:GameUnzip error:nil];
        for (NSString *file in contents) {
            NSString *filePath = [GameUnzip stringByAppendingPathComponent:file];
            [manager removeItemAtPath:filePath error:nil];
        }
    }
    
}

- (NSArray *)lackSupportUtility {
    NSMutableArray *result = @[].mutableCopy;
    
    if (![manager fileExistsAtPath:@"/usr/bin/zip"]) {
        [result addObject:@"/usr/bin/zip"];
    }
    if (![manager fileExistsAtPath:@"/usr/bin/unzip"]) {
        [result addObject:@"/usr/bin/unzip"];
    }
    if (![manager fileExistsAtPath:@"/usr/bin/codesign"]) {
        [result addObject:@"/usr/bin/codesign"];
    }
    
    return result.copy;
}
- (void)getCertificatesLog:(void (^)(NSString * _Nonnull))logBlock error:(void (^)(NSString * _Nonnull))errorBlock success:(void (^)(NSArray * _Nonnull))successBlock {
    NSTask *certTask = [[NSTask alloc] init];
    [certTask setLaunchPath:@"/usr/bin/security"];
    [certTask setArguments:[NSArray arrayWithObjects:@"find-identity", @"-v", @"-p", @"codesigning", nil]];
    
    NSPipe *pipe = [NSPipe pipe];
    [certTask setStandardOutput:pipe];
    [certTask setStandardError:pipe];
    NSFileHandle *handle = [pipe fileHandleForReading];

    [certTask launch];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //检查KeyChain中是否有证书，然后把证书保存到certificatesArray
        NSString *securityResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        logBlock([NSString stringWithFormat:@"签名证书列表：%@", securityResult]);
        if (securityResult == nil || securityResult.length < 1) return;
        NSArray *rawResult = [securityResult componentsSeparatedByString:@"\""];
        NSMutableArray *tempGetCertsResult = [NSMutableArray arrayWithCapacity:20];
        for (int i = 0; i <= [rawResult count] - 2; i += 2) {
            if (!(rawResult.count - 1 < i + 1)) {
                [tempGetCertsResult addObject:[rawResult objectAtIndex:i+1]];
            }
        }
        
        __block NSMutableArray *certificatesArray = [NSMutableArray arrayWithArray:tempGetCertsResult];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (certificatesArray.count > 0) {
                if (successBlock != nil) {
                    successBlock(certificatesArray.copy);
                }
            } else {
                if (errorBlock != nil) {
                    errorBlock(@"没有找到签名证书");
                }
            }
        });
    });
}

- (NSArray *)getProvisioningProfiles {
    NSArray *provisioningProfiles = [manager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), kMobileprovisionDirName] error:nil];
    provisioningProfiles = [provisioningProfiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", provisionExtensions]];
    
    NSMutableArray *provisioningArray = @[].mutableCopy;
    [provisioningProfiles enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *path = (NSString *)obj;
        BOOL isDirectory;
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@/%@", NSHomeDirectory(), kMobileprovisionDirName, path];
        if ([self->manager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            ZCProvisioningProfile *profile = [[ZCProvisioningProfile alloc] initWithPath:fullPath];
            [provisioningArray addObject:profile];
        }
    }];
    
    provisioningArray = [[provisioningArray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [((ZCProvisioningProfile *)obj1).name compare:((ZCProvisioningProfile *)obj2).name];
    }] mutableCopy];
    
    return provisioningArray.copy;
}

#pragma mark - unzip zip
- (void)copyFile:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL))completeBlock {
    if (![manager fileExistsAtPath:sourcePath]) {
        completeBlock(NO);
    }
    if ([manager fileExistsAtPath:targetPath]) {
        [manager removeItemAtPath:targetPath error:nil];
    }
    BOOL copySuccess = [manager copyItemAtPath:sourcePath toPath:targetPath error:nil];
    if (copySuccess) {
        completeBlock(YES);
    } else {
        completeBlock(NO);
    }
}
- (void)copyFiles:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL))completeBlock {
    NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:sourcePath error:nil];
    ZCManuaQueue *queue = [[ZCManuaQueue alloc] init];
    __block NSString *failureCopyFile;
    for (NSString *file in sourceContents) {
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            NSString *sourcefilePath = [sourcePath stringByAppendingPathComponent:file];
            NSString *targetfilePath = [targetPath stringByAppendingPathComponent:file];
            ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
            [runloop run:^{
                [self copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                    [runloop stop:^{
                        if (result) {
                            [queue next];
                        } else {
                            failureCopyFile = sourcefilePath;
                            [queue cancelAll];
                        }
                    }];
                }];
            }];
        }];
        [queue addOperation:operation];
    }
    [queue next];
    queue.noOperationBlock = ^{
        if (completeBlock && failureCopyFile == nil) {
            completeBlock(YES);
        } else {
            completeBlock(NO);
        }
    };
}
- (void)unzip:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL))completeBlock {
    if (![manager fileExistsAtPath:sourcePath]) {
        completeBlock(NO);
    }
    
    NSTask *unzipTask = [[NSTask alloc] init];
    [unzipTask setLaunchPath:@"/usr/bin/unzip"];
    [unzipTask setArguments:[NSArray arrayWithObjects:sourcePath, @"-d", targetPath, nil]];
    [unzipTask launch];
    
    ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
    [runloop run:^{
        if ([unzipTask isRunning] == 0) {
            [runloop stop:^{
                if (unzipTask.terminationStatus == 0) {
                    if ([self->manager fileExistsAtPath:targetPath]) {
                        completeBlock(YES);
                    }
                } else {
                    completeBlock(NO);
                }
            }];
        }
    }];
}

- (void)zip:(NSString *)sourcepath toPath:(NSString *)targetPath complete:(void (^)(BOOL))completeBlock {
    if (![manager fileExistsAtPath:sourcepath]) {
        completeBlock(NO);
    }
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/zip"];
    [task setArguments:@[@"-qry", targetPath, @"."]];
    [task setCurrentDirectoryPath:sourcepath];
    [task launch];
    
    ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
    [runloop run:^{
        if ([task isRunning] == 0) {
            [runloop stop:^{
                if (task.terminationStatus == 0) {
                    if ([self->manager fileExistsAtPath:targetPath]) {
                        completeBlock(YES);
                    } else {
                        completeBlock(NO);
                    }
                } else {
                    completeBlock(NO);
                }
            }];
        }
    }];
}

- (void)getAppIcon:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL))completeBlock {
    if (![manager fileExistsAtPath:sourcePath]) {
        completeBlock(NO);
    }
    
    NSString *AssetsPath = [targetPath stringByAppendingPathComponent:@"Assets.xcassets"];
    NSString *AppIconPath = [AssetsPath stringByAppendingPathComponent:@"AppIcon.appiconset"];
    if (![self->manager fileExistsAtPath:AppIconPath]) {
        [self->manager createDirectoryAtPath:AppIconPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    
    NSString *localData_plist = [[NSBundle mainBundle] pathForResource:@"ZCLocalData" ofType:@"plist"];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:localData_plist];
    ZCAppIconModel *appIconModel = [ZCAppIconModel mj_objectWithKeyValues:data[@"appicon"]];
    
    //创建Cosntents.json
    NSData *jsonData = [appIconModel mj_JSONData];
    // 指定 JSON 文件路径
    NSString *ContentsPath = [AppIconPath stringByAppendingPathComponent:@"Contents.json"];
    // 将 JSON 数据写入文件
    if ([jsonData writeToFile:ContentsPath atomically:YES]) {
        NSLog(@"JSON file created successfully at %@", ContentsPath);
    } else {
        NSLog(@"Error writing JSON data to file");
    }
    //创建AppIcon图片
    for (ZCAppIconImageItem *iconImageItem in appIconModel.images) {
        NSArray *sizeArr = [iconImageItem.size componentsSeparatedByString:@"x"];
        NSArray *scaleArr = [iconImageItem.scale componentsSeparatedByString:@"x"];
        int width = [sizeArr[0] intValue];
//        int height = [sizeArr[1] intValue];
        int scale = [scaleArr[0] intValue];
        NSString *arguments1 = [NSString stringWithFormat:@"%d", width*scale];

        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/sips"];

        
        NSString *targetPath_png = [AppIconPath stringByAppendingPathComponent:iconImageItem.filename];
        // 设置命令行参数
        NSArray *arguments = @[@"-z", arguments1, arguments1, sourcePath, @"--out", targetPath_png];
        [task setArguments:arguments];
        // 启动任务
        [task launch];
        [task waitUntilExit];
        // 获取任务的退出状态
        int status = [task terminationStatus];
        if (status == 0) {
            NSLog(@"sips command executed successfully!");
        } else {
            NSLog(@"Error executing sips command. Exit code: %d", status);
        }
    }
    
    
    
    
    // 创建 NSTask 对象
    NSTask *task = [[NSTask alloc] init];
    
    // 设置命令路径和参数
    [task setLaunchPath:@"/usr/bin/xcrun"];
    [task setArguments:@[@"actool",
                         @"--output-format", @"human-readable-text",
                         @"--notices",
                         @"--warnings",
                         @"--platform", @"macosx",
                         @"--minimum-deployment-target", @"10.12",
                         @"--app-icon", @"AppIcon",
                         @"--output-partial-info-plist", @"PartialInfo.plist",
                         @"--compress-pngs",
                         @"--enable-on-demand-resources", @"YES",
                         @"--filter-for-device-model", @"Mac",
                         @"--filter-for-device-os-version", @"10.12",
                         @"--sticker-pack-identifier-prefix", @"1",
                         @"--target-device", @"ipad",
                         @"--target-device", @"iphone",
                         @"--output-dir", targetPath,
                         AssetsPath]];
    
    // 设置当前工作目录
    [task setCurrentDirectoryPath:@"/path/to/your/project"];
    
    // 创建管道用于捕获输出
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    // 启动任务
    [task launch];
    
    // 等待任务完成
    [task waitUntilExit];
    
    // 从管道中获取输出
    NSFileHandle *fileHandle = [pipe fileHandleForReading];
    NSData *outputData = [fileHandle readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    
    // 输出任务的标准输出
    NSLog(@"Task Output:\n%@", outputString);
    
    // 检查任务的退出状态
    if ([task terminationStatus] == 0) {
        NSLog(@"Task completed successfully");
    } else {
        NSLog(@"Task failed with exit code: %d", [task terminationStatus]);
    }
    
    completeBlock(YES);
}




@end
