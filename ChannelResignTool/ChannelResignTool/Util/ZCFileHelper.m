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

- (void)getAppIcon:(NSString *)appIconPath complete:(void (^)(BOOL result))completeBlock {
    if (![manager fileExistsAtPath:appIconPath]) {
        completeBlock(NO);
    }
    /*
     CFBundleIcons
     "AppIcon20x20",
     "AppIcon29x29",
     "AppIcon40x40",
     "AppIcon57x57",
     "AppIcon60x60"
     
     CFBundleIcons~ipad
     "AppIcon20x20",
     "AppIcon29x29",
     "AppIcon40x40",
     "AppIcon57x57",
     "AppIcon60x60",
     "AppIcon50x50",
     "AppIcon72x72",
     "AppIcon76x76",
     "AppIcon83.5x83.5"
     */
    NSString *localData_plist = [[NSBundle mainBundle] pathForResource:@"ZCLocalData" ofType:@"plist"];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:localData_plist];
    NSMutableArray *iconnums = data[@"iconnums"];
    
    for (NSDictionary *dict in iconnums) {

        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/sips"];

        NSString *AppIcons = [[CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"GameUnzip"] stringByAppendingPathComponent:@"AppIcons"];
        if (![manager fileExistsAtPath:AppIcons]) {
            [manager createDirectoryAtPath:AppIcons withIntermediateDirectories:YES attributes:nil error:nil];
        }
        [manager createDirectoryAtPath:AppIcons withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *targetPath_png = [[AppIcons stringByAppendingPathComponent:dict[@"name"]] stringByAppendingPathExtension:@"png"];
        // 设置命令行参数
        NSArray *arguments = @[@"-z", dict[@"resolution"], dict[@"resolution"], appIconPath, @"--out", targetPath_png];
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
    
    
    
    completeBlock(YES);
}




@end
