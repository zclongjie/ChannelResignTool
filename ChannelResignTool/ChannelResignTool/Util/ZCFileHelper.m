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
#import "ZCPlatformModel.h"
#import "NSImage+ZCUtil.h"

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

- (NSMutableArray *)platformArray {
    if (!_platformArray) {
        _platformArray = [NSMutableArray array];
    }
    return _platformArray;
}

- (void)appSpace {
    
    NSString *PlatformSDKDownloadZip = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"PlatformSDKDownloadZip"];
    NSString *PlatformSDKJson = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"PlatformSDKJson"];
    NSString *PlatformSDKUnzip = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"PlatformSDKUnzip"];
    NSString *GameUnzip = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"GameUnzip"];
    //创建新目录
    if (![manager fileExistsAtPath:PlatformSDKDownloadZip]) {
        [manager createDirectoryAtPath:PlatformSDKDownloadZip withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![manager fileExistsAtPath:PlatformSDKJson]) {
        [manager createDirectoryAtPath:PlatformSDKJson withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![manager fileExistsAtPath:PlatformSDKUnzip]) {
        [manager createDirectoryAtPath:PlatformSDKUnzip withIntermediateDirectories:YES attributes:nil error:nil];
    } else {
        NSArray *contents = [self->manager contentsOfDirectoryAtPath:PlatformSDKUnzip error:nil];
        for (NSString *file in contents) {
            NSString *filePath = [PlatformSDKUnzip stringByAppendingPathComponent:file];
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
    

#warning PlatformSDKJson 这里更新全部渠道json文件
    
#warning PlatformSDKConfig 这里执行渠道配置下载
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
    [self.platformArray addObject:model];
    
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
    [self.platformArray addObject:model2];
    
    
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

- (void)downloadPlatformSDKWithPlatformId:(NSString *)platformId log:(FileHelperLogBlock)logBlock error:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock {
#warning PlatformSDKDownloadZip 这里执行渠道sdk下载操作

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        successBlock([NSString stringWithFormat:@"渠道%@下载成功", platformId]);
    });
    
//    // SVN 仓库地址和目标文件路径
//    NSString *svnRepositoryURL = @"svn://svn.wan73.com/project/doc/SDK";
//    NSString *PlatformSDKDownloadZip = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"PlatformSDKDownloadZip"];
//
//    // 创建 NSTask 对象
//    NSTask *svnTask = [[NSTask alloc] init];
//
//    // 设置要执行的命令（/usr/bin/svn）
//    [svnTask setLaunchPath:[NSHomeDirectory() stringByAppendingPathComponent:@"svn"]];
//
//    // 设置 svn 的参数，包括 checkout 命令和仓库地址
//    [svnTask setArguments:@[@"checkout", svnRepositoryURL, PlatformSDKDownloadZip]];
//
//    // 启动任务
//    [svnTask launch];
//    [svnTask waitUntilExit];
//
//    // 获取任务的退出状态
//    int terminationStatus = [svnTask terminationStatus];
//    NSLog(@"svn Task completed with exit code: %d", terminationStatus);
//
//    // 输出下载后的文件路径
//    NSLog(@"下载后的文件路径: %@", PlatformSDKDownloadZip);
//
//    successBlock([NSString stringWithFormat:@"渠道%@下载成功", platformId]);
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

- (void)getAppIcon:(NSString *)sourcePath markerPath:(NSString *)markerPath toPath:(NSString *)targetPath log:(FileHelperLogBlock)logBlock error:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock {
    if (![manager fileExistsAtPath:sourcePath]) {
        errorBlock([NSString stringWithFormat:@"%@不存在", sourcePath]);
        return;
    }
    
    NSString *AssetsPath = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"Assets.xcassets"];
    NSString *AppIconPath = [AssetsPath stringByAppendingPathComponent:@"AppIcon.appiconset"];
    if (![self->manager fileExistsAtPath:AppIconPath]) {
        [self->manager createDirectoryAtPath:AppIconPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    //生成AppIcon.appiconset
    [self createAppIcon:sourcePath markerPath:markerPath toPath:AppIconPath log:^(NSString * _Nonnull logString) {
        logBlock(logString);
    } error:^(NSString * _Nonnull errorString) {
        errorBlock(errorString);
    } success:^(id  _Nonnull message) {
        
        //复制图片到临时项目
        [self copyAppIcon:AppIconPath log:^(NSString * _Nonnull logString) {
            logBlock(logString);
        } error:^(NSString * _Nonnull errorString) {
            errorBlock(errorString);
        } success:^(id  _Nonnull message) {
            logBlock(message);
            [self buildAppIconError:^(NSString * _Nonnull errorString) {
                errorBlock(errorString);
            } success:^(id  _Nonnull message) {
                logBlock(message);
                //移动Assets到目标app
                [self moveAssetsToPath:targetPath error:^(NSString * _Nonnull errorString) {
                    errorBlock(errorString);
                } success:^(id  _Nonnull message) {
                    successBlock(message);
                }];
            }];
        }];
        
    }];
    
}

- (void)createAppIcon:(NSString *)sourcePath markerPath:(NSString *)markerPath toPath:(NSString *)targetPath log:(FileHelperLogBlock)logBlock error:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock {
    
    NSString *outputImagePath = sourcePath;
    if (markerPath) {
        //合并角标
        // 合并后的图片保存路径
        outputImagePath = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"mergedImage.png"];

        NSImage *image1 = [[NSImage alloc] initWithContentsOfFile:sourcePath];
        NSImage *image2 = [[NSImage alloc] initWithContentsOfFile:markerPath];

        NSImage *mergedImage = [NSImage mergeImages:image1 withImage:image2];
        [NSImage saveMergedImage:mergedImage toPath:outputImagePath];

    }
    
    NSString *localData_plist = [[NSBundle mainBundle] pathForResource:@"ZCLocalData" ofType:@"plist"];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:localData_plist];
    ZCAppIconModel *appIconModel = [ZCAppIconModel mj_objectWithKeyValues:data[@"appicon"]];
    
    //创建Cosntents.json
    NSData *jsonData = [appIconModel mj_JSONData];
    // 指定 JSON 文件路径
    NSString *ContentsPath = [targetPath stringByAppendingPathComponent:@"Contents.json"];
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
        int scale = [scaleArr[0] intValue];
        NSString *arguments1 = [NSString stringWithFormat:@"%d", width*scale];

        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/sips"];

        NSString *targetPath_png = [targetPath stringByAppendingPathComponent:iconImageItem.filename];
        // 设置命令行参数
        NSArray *arguments = @[@"-z", arguments1, arguments1, outputImagePath, @"--out", targetPath_png];
        [task setArguments:arguments];
        // 启动任务
        [task launch];
        [task waitUntilExit];
        // 获取任务的退出状态
        int status = [task terminationStatus];
        if (status == 0) {
            logBlock([NSString stringWithFormat:@"appicon %@ 成功", targetPath_png]);
        } else {
            errorBlock([NSString stringWithFormat:@"appicon %@ 失败", targetPath_png]);
            break;
        }
    }
    
    successBlock(@"appicon生成完成");
    
}

- (void)copyAppIcon:(NSString *)sourcePath log:(FileHelperLogBlock)logBlock error:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock {
    // Xcode 项目根目录
    NSString *projectDirectory = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"ZCTemp"];
    // Asset Catalog 文件夹相对路径
    NSString *assetsCatalogRelativePath = [projectDirectory stringByAppendingPathComponent:@"ZCTemp/Assets.xcassets"];
    //将AppIconPath移到ZCTemp->Assets.xcassets
    NSString *AppIcon_appiconset = [assetsCatalogRelativePath stringByAppendingPathComponent:@"AppIcon.appiconset"];
    if ([self->manager fileExistsAtPath:AppIcon_appiconset]) {
        [self->manager removeItemAtPath:AppIcon_appiconset error:nil];
    }
    [self->manager createDirectoryAtPath:AppIcon_appiconset withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSArray *AppIconsPathContents = [self->manager contentsOfDirectoryAtPath:sourcePath error:nil];
    for (NSString *file in AppIconsPathContents) {
        NSString *sourcefilePath = [sourcePath stringByAppendingPathComponent:file];
        // 创建 NSTask 对象
        NSTask *mvTask = [[NSTask alloc] init];
        // 设置要执行的命令（mv）
        [mvTask setLaunchPath:@"/bin/cp"];
        // 设置 mv 的参数
        [mvTask setArguments:@[sourcefilePath, AppIcon_appiconset]];
        // 启动任务
        [mvTask launch];
        [mvTask waitUntilExit];

        // 获取任务的退出状态
        int status = [mvTask terminationStatus];
        if (status == 0) {
            logBlock([NSString stringWithFormat:@"appicon %@ 复制成功", file]);
        } else {
            errorBlock([NSString stringWithFormat:@"appicon %@ 复制失败", file]);
            break;
        }
    }
    successBlock(@"appicon复制到项目完成");
}

- (void)buildAppIconError:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock {
    // Xcode 项目根目录
    NSString *projectDirectory = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"ZCTemp"];
    // 创建 NSTask 对象
    NSTask *xcodebuildTask = [[NSTask alloc] init];
    // 设置要执行的命令（actool）
    [xcodebuildTask setLaunchPath:@"/usr/bin/xcrun"];
    // 设置 xcodebuild 的参数
    [xcodebuildTask setArguments:@[@"xcodebuild",
                                   @"-project", [projectDirectory stringByAppendingPathComponent:@"ZCTemp.xcodeproj"],
                                   @"-target", @"ZCTemp",  // 替换为你的目标名称
                                   @"-configuration", @"Release",  // 或者使用 "Debug"
                                   @"-sdk", @"iphonesimulator",  // 或者使用 "iphonesimulator" 等
                                   @"build"]];
    // 启动任务
    [xcodebuildTask launch];
    [xcodebuildTask waitUntilExit];
    // 获取任务的退出状态
    int xcodebuildTerminationStatus = [xcodebuildTask terminationStatus];
    if (xcodebuildTerminationStatus == 0) {
        successBlock(@"appicon build 成功");
    } else {
        errorBlock(@"appicon build 失败");
    }
}

- (void)moveAssetsToPath:(NSString *)targetPath error:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock {
    // Xcode 项目根目录
    NSString *ReleasePath = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"ZCTemp/build/Release-iphonesimulator"];
    NSArray *ReleaseContents = [manager contentsOfDirectoryAtPath:ReleasePath error:nil];
    __block NSString *appPath;
    [ReleaseContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *file = (NSString *)obj;
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [ReleasePath stringByAppendingPathComponent:file];
            *stop = YES;
        }
    }];
    NSString *assetsCarPath = [appPath stringByAppendingPathComponent:@"Assets.car"];
    if ([manager fileExistsAtPath:assetsCarPath]) {
        // 创建 NSTask 对象
        NSTask *mvTask = [[NSTask alloc] init];
        // 设置要执行的命令（mv）
        [mvTask setLaunchPath:@"/bin/mv"];
        // 设置 mv 的参数
        [mvTask setArguments:@[assetsCarPath, targetPath]];
        // 启动任务
        [mvTask launch];
        [mvTask waitUntilExit];

        // 获取任务的退出状态
        int status = [mvTask terminationStatus];
        if (status == 0) {
            successBlock(@"Assets 移动 成功");
        } else {
            errorBlock(@"Assets 移动 失败");
        }
    } else {
        errorBlock(@"Assets.car文件不存在");
    }
    
    
}


@end
