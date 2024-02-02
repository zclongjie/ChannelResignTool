//
//  ZCAppPackageHandler.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import "ZCAppPackageHandler.h"
#import "ZCFileHelper.h"
#import "ZCDateFormatterUtil.h"
#import "ZCRunLoop.h"
#import "ZCManuaQueue.h"
#import "ZCDataUtil.h"
#import "ZCAppIconModel.h"

@implementation ZCAppPackageHandler {
    NSFileManager *manager;//全局文件管理
    NSString *entitlementsResult;//创建entitlementss任务的结果
    NSString *codesigningResult;//签名任务的结果
    NSString *verificationResult;//验证签名任务的结果
}

- (instancetype)initWithPackagePath:(NSString *)path {
    self = [super init];
    if (self) {
        manager = [NSFileManager defaultManager];
        
        self.packagePath = path;
        
        //生成临时解压路径（此时目录还未创建）
        NSString *ipaPathName = [[self.packagePath lastPathComponent] stringByDeletingPathExtension];//从文件的最后一部分删除扩展名
        self.workPath = [[ZCFileHelper sharedInstance].GameTemp stringByAppendingPathComponent:ipaPathName];
        
    }
    return self;
}

- (BOOL)removeCodeSignatureDirectory {
    NSString *codeSignaturePath = [self.appPath stringByAppendingPathComponent:kCodeSignatureDirectory];
    if (codeSignaturePath && [manager fileExistsAtPath:codeSignaturePath]) {
        return [manager removeItemAtPath:codeSignaturePath error:nil];
    } else if (![manager fileExistsAtPath:codeSignaturePath]) {
        return YES;
    }
    return NO;
}

#pragma mark - unzip
- (void)unzipIpaLog:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    if ([self.packagePath.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
        
        //移除之前的解压路径
        if ([manager fileExistsAtPath:self.workPath]) {
            [manager removeItemAtPath:self.workPath error:nil];
        }
        //创建新目录
        [manager createDirectoryAtPath:self.workPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        //解压
        [[ZCFileHelper sharedInstance] unzip:self.packagePath toPath:self.workPath complete:^(BOOL result) {
            if (result) {
                [self setAppPath];
                if (successBlock) {
                    successBlock(BlockType_Unzip, @"文件解压完成");
                }
            } else {
                errorBlock(BlockType_Unzip, @"文件解压失败");
            }
        }];
        
    } else if ([self.packagePath.pathExtension.lowercaseString isEqualToString:@"app"]) {
        
        //移除之前的解压路径
        if ([manager fileExistsAtPath:self.workPath]) {
            [manager removeItemAtPath:self.workPath error:nil];
        }
        //创建新目录
        NSString *payloadPath = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
        [manager createDirectoryAtPath:payloadPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *targetPath = [payloadPath stringByAppendingPathComponent:self.packagePath.lastPathComponent];
        
        [[ZCFileHelper sharedInstance] copyFile:self.packagePath toPath:targetPath complete:^(BOOL result) {
            if (result) {
                [self setAppPath];
                if (successBlock) {
                    successBlock(BlockType_Unzip, @"文件复制完成");
                }
            } else {
                errorBlock(BlockType_Unzip, @"文件复制失败");
            }
        }];
        
    } else {
        if (errorBlock) {
            errorBlock(BlockType_Unzip, [NSString stringWithFormat:@"文件扩展名不是ipa或app"]);
        }
    }
}

#pragma mark - App Info
- (void)setAppPath {
    NSString *payloadPath = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *payloadContents = [manager contentsOfDirectoryAtPath:payloadPath error:nil];
    [payloadContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *file = (NSString *)obj;
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            self.appPath = [[self.workPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            *stop = YES;
        }
    }];
}
- (NSString *)bundleDisplayName {
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *infoPlistDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *displayName = infoPlistDict[kCFBundleDisplayName];
        if (displayName) {
            return displayName;
        } else {
            return @"info.plist文件中不存在 CFBundleDisplayName";
        }
    } else {
        return @"info.plist文件不存在";
    }
}
- (NSString *)bundleID {
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *infoPlistDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *bundleIdentifier = infoPlistDict[kCFBundleIdentifier];
        if (bundleIdentifier) {
            return bundleIdentifier;
        } else {
            return @"info.plist文件中不存在 CFBundleIdentifier";
        }
    } else {
        return @"info.plist文件不存在";
    }
}

#pragma mark - Resign
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certificateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    /*
     1.创建新的entitlements
     2.修改info.plist
     3.修改Embedded Provision
     4.开始签名并验证
     5.压缩文件
     */
    
    //1.创建新的entitlements
    [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
        if (logBlock) {
            logBlock(BlockType_Entitlements, logString);
        }
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        if (errorBlock) {
            errorBlock(BlockType_Entitlements, errorString);
        }
    } success:^(BlockType type, id  _Nonnull message) {
        if (successBlock) {
            successBlock(BlockType_Entitlements, message);
        }
        
        //2.修改info.plist
        [self editInfoPlistWithIdentifier:bundleIdentifier displayName:displayName log:^(BlockType type, NSString * _Nonnull logString) {
            if (logBlock) {
                logBlock(BlockType_InfoPlist, logString);
            }
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            if (errorBlock) {
                errorBlock(BlockType_InfoPlist, errorString);
            }
        } success:^(BlockType type, id  _Nonnull message) {
            if (successBlock) {
                successBlock(BlockType_InfoPlist, message);
            }
            
            //3.修改Embedded Provision
            [self editEmbeddedProvision:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                if (logBlock) {
                    logBlock(BlockType_EmbeddedProvision, logString);
                }
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                if (errorBlock) {
                    errorBlock(BlockType_EmbeddedProvision, errorString);
                }
            } success:^(BlockType type, id  _Nonnull message) {
                if (successBlock) {
                    successBlock(BlockType_EmbeddedProvision, message);
                }
                
                //4.开始签名
                [self doCodesignCertificateName:certificateName log:^(BlockType type, NSString * _Nonnull logString) {
                    if (logBlock) {
                        logBlock(BlockType_DoCodesign, logString);
                    }
                } error:^(BlockType type, NSString * _Nonnull errorString) {
                    if (errorBlock) {
                        errorBlock(BlockType_DoCodesign, errorString);
                    }
                } success:^(BlockType type, id  _Nonnull message) {
                    if (successBlock) {
                        successBlock(BlockType_DoCodesign, message);
                    }
                    
                    //5.压缩文件
                    [self zipPackageToDirPath:targetPath PlatformModel:nil log:^(BlockType type, NSString * _Nonnull logString) {
                        
                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                        if (errorBlock) {
                            errorBlock(BlockType_ZipPackage, errorString);
                        }
                    } success:^(BlockType type, id  _Nonnull message) {
                        if (successBlock) {
                            successBlock(BlockType_ZipPackage, message);
                        }
                    }];
                    
                }];
            }];
        }];
    }];
}

#pragma mark - Entitlements
- (void)createEntitlementsWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_Entitlements, @"创建Entitlements……");
    }
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [manager fileExistsAtPath:entitlementsPath]) {
        if (![manager removeItemAtPath:entitlementsPath error:nil]) {
            if (errorBlock) {
                errorBlock(BlockType_Entitlements, @"错误：删除旧Entitlements失败");
            }
            return;
        }
    }
    
    //使用provisioningProfile作为新的Entitlements
    if ([manager fileExistsAtPath:provisioningProfile.path]) {
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/security"];
        [task setArguments:@[@"cms", @"-D", @"-i", provisioningProfile.path]];
        [task setCurrentDirectoryPath:self.workPath];
        
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        [task setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];
        [task launch];
        
        ZCRunLoop *runLoop = [[ZCRunLoop alloc] init];
        [runLoop run:^{
            if (task.isRunning == 0) {
                [runLoop stop:^{
                    if (task.terminationStatus == 0) {
                        if ([self->entitlementsResult respondsToSelector:@selector(containsString:)] && [self->entitlementsResult containsString:@"SecPolicySetValue"]) {
                            NSMutableArray *linesInOutput = [self->entitlementsResult componentsSeparatedByString:@"\n"].mutableCopy;
                            [linesInOutput removeObjectAtIndex:0];
                            self->entitlementsResult = [linesInOutput componentsJoinedByString:@"\n"];
                        }
                        NSMutableDictionary *entitlementsDict = [[NSMutableDictionary alloc] initWithDictionary:self->entitlementsResult.propertyList[@"Entitlements"]];
                        /*
                         {
                             "application-identifier" = "53V38J3HUU.com.*";
                             "com.apple.developer.team-identifier" = 53V38J3HUU;
                             "get-task-allow" = 1;
                             "keychain-access-groups" =     (
                                 "53V38J3HUU.*",
                                 "com.apple.token"
                             );
                         }
                         */
                        NSString *filePath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
                        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlementsDict format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
                        if ([xmlData writeToFile:filePath atomically:YES]) {
                            if (successBlock) {
                                successBlock(BlockType_Entitlements, @"Entitlements.plist创建成功");
                            }
                        } else {
                            if (errorBlock) {
                                errorBlock(BlockType_Entitlements, @"Entitlements.plist写入数据失败");
                            }
                        }
                    } else {
                        if (errorBlock) {
                            errorBlock(BlockType_Entitlements, @"创建Entitlements失败");
                        }
                    }
                }];
            }
        }];
        [NSThread detachNewThreadSelector:@selector(watchEntitlements:) toTarget:self withObject:handle];
    } else {
        if (errorBlock) {
            errorBlock(BlockType_Entitlements, @"选择的provisioning profile不存在");
        }
    }
}
- (void)watchEntitlements:(NSFileHandle *)handle {
    @autoreleasepool {
        entitlementsResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

#pragma mark - Info.plist
- (void)editInfoPlistWithIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_InfoPlist, @"修改info.plist……");
    }
    
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:displayName forKey:kCFBundleDisplayName];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successBlock) {
                successBlock(BlockType_InfoPlist, @"Info.plist修改完成");
            }
        } else {
            if (errorBlock) {
                errorBlock(BlockType_InfoPlist, @"Info.plist写入失败");
            }
        }
    } else {
        if (errorBlock) {
            errorBlock(BlockType_InfoPlist, @"Info.plist未找到");
        }
    }
}

- (void)platformeditInfoPlistWithPlatformModel:(ZCPlatformModel *)platformModel log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_InfoPlist, @"修改info.plist……");
    }
        
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:platformModel.bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:platformModel.gameName forKey:kCFBundleDisplayName];
        
        [plist setObject:@"LaunchImage" forKey:kUILaunchImageFile];
        
        if ([platformModel.isLan isEqualToString:@"0"]) {
            [plist setObject:@"LaunchPortrait" forKey:kUILaunchStoryboardName];
            [plist setObject:@"LaunchPortrait" forKey:kUILaunchStoryboardNameipad];
            [plist setObject:@"LaunchPortrait" forKey:kUILaunchStoryboardNameiphone];
        } else {
            [plist setObject:@"LaunchLandscape" forKey:kUILaunchStoryboardName];
            [plist setObject:@"LaunchLandscape" forKey:kUILaunchStoryboardNameipad];
            [plist setObject:@"LaunchLandscape" forKey:kUILaunchStoryboardNameiphone];
        }
        
        
        NSString *localData_plist = [[NSBundle mainBundle] pathForResource:@"ZCLocalData" ofType:@"plist"];
        NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:localData_plist];
        ZCAppIconModel *appIconModel = [ZCAppIconModel mj_objectWithKeyValues:data[@"appicon"]];
        
        NSMutableArray *CFBundleIconFiles_iPad = @[].mutableCopy;
        NSMutableArray *CFBundleIconFiles_iPhone = @[].mutableCopy;
        for (ZCAppIconImageItem *iconImageItem in appIconModel.images) {
            NSString *CFBundleIconFilesName = [NSString stringWithFormat:@"AppIcon%@", iconImageItem.size];
            if ([iconImageItem.idiom isEqualToString:@"iphone"]) {
                if (![CFBundleIconFiles_iPhone containsObject:CFBundleIconFilesName]) {
                    [CFBundleIconFiles_iPhone addObject:CFBundleIconFilesName];
                }
            }
            if ([iconImageItem.idiom isEqualToString:@"ipad"]) {
                if (![CFBundleIconFiles_iPad containsObject:CFBundleIconFilesName]) {
                    [CFBundleIconFiles_iPad addObject:CFBundleIconFilesName];
                }
            }
        }
        if (CFBundleIconFiles_iPad.count) {
            NSMutableDictionary *CFBundlePrimaryIcon = @{}.mutableCopy;
            [CFBundlePrimaryIcon setObject:CFBundleIconFiles_iPad forKey:@"CFBundleIconFiles"];
            [CFBundlePrimaryIcon setObject:@"AppIcon" forKey:@"CFBundleIconName"];
            [plist setObject:@{@"CFBundlePrimaryIcon": CFBundlePrimaryIcon} forKey:@"CFBundleIcons~ipad"];
        }
        if (CFBundleIconFiles_iPhone.count) {
            NSMutableDictionary *CFBundlePrimaryIcon = @{}.mutableCopy;
            [CFBundlePrimaryIcon setObject:CFBundleIconFiles_iPhone forKey:@"CFBundleIconFiles"];
            [CFBundlePrimaryIcon setObject:@"AppIcon" forKey:@"CFBundleIconName"];
            [plist setObject:@{@"CFBundlePrimaryIcon": CFBundlePrimaryIcon} forKey:@"CFBundleIcons"];
        }
        
        
        //添加渠道info.plist信息
        //1.获取渠道json文件（实际为网络下载）
        NSString *platformJsonPath = [[[ZCFileHelper sharedInstance].PlatformSDKJson stringByAppendingPathComponent:platformModel.platformId] stringByAppendingPathExtension:@"json"];
        NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonPath];
        //替换参数值 如{package}
        [self gamePlistInjectValue:platformJsonPlist platformModel:platformModel];
        NSMutableDictionary *game_plist = platformJsonPlist[@"game_plist"];
        for (NSString *key in game_plist.allKeys) {
            id value = game_plist[key];
            if ([plist.allKeys containsObject:key]) {
                if ([value isKindOfClass:[NSArray class]]) {
                    NSMutableArray *valueArray = plist[key];
                    [valueArray addObjectsFromArray:value];
                    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithArray:valueArray];
                    NSArray *uniqueArray = [orderedSet array];
                    [plist setObject:uniqueArray forKey:key];
                } else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *valueDict = plist[key];
                    [valueDict addEntriesFromDictionary:value];
                    [plist setObject:valueDict forKey:key];
                } else if ([value isKindOfClass:[NSString class]]) {
                    [plist setObject:value forKey:key];
                }
            } else {
                [plist setObject:value forKey:key];
            }
        }
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successBlock) {
                successBlock(BlockType_InfoPlist, @"Info.plist修改完成");
            }
        } else {
            if (errorBlock) {
                errorBlock(BlockType_InfoPlist, @"Info.plist写入失败");
            }
        }
    } else {
        if (errorBlock) {
            errorBlock(BlockType_InfoPlist, @"Info.plist未找到");
        }
    }
}
- (void)gamePlistInjectValue:(NSMutableDictionary *)platformJsonPlist platformModel:(ZCPlatformModel *)model {
    NSMutableDictionary *game_plist = platformJsonPlist[@"game_plist"];
    NSMutableDictionary *replace = platformJsonPlist[@"replace"];
    for (NSString *replacekey in replace.allKeys) {
        NSString *replacevalue = model.parameter[replace[replacekey]];
        for (NSString *key in game_plist.allKeys) {
            id value = game_plist[key];
            if ([value isKindOfClass:[NSArray class]]) {
                [self replaceArray:value replacekey:replacekey replacevalue:replacevalue];
            } else if ([value isKindOfClass:[NSDictionary class]]) {
                [self replaceDict:value replacekey:replacekey replacevalue:replacevalue];
            } else if ([value isKindOfClass:[NSString class]]) {
                if ([value containsString:replacekey]) {
                    [game_plist setObject:[value stringByReplacingOccurrencesOfString:replacekey withString:replacevalue] forKey:key];
                }
            }
        }
    }
}
- (void)replaceDict:(NSMutableDictionary *)dict replacekey:(NSString *)replacekey replacevalue:(NSString *)replacevalue {
    for (NSString *key in dict.allKeys) {
        id valueDictId = dict[key];
        if ([valueDictId isKindOfClass:[NSArray class]]) {
            [self replaceArray:valueDictId replacekey:replacekey replacevalue:replacevalue];
        } else if ([valueDictId isKindOfClass:[NSDictionary class]]) {
            [self replaceDict:valueDictId replacekey:replacekey replacevalue:replacevalue];
        } else if ([valueDictId isKindOfClass:[NSString class]]) {
            if ([valueDictId containsString:replacekey]) {
                [dict setObject:[valueDictId stringByReplacingOccurrencesOfString:replacekey withString:replacevalue] forKey:key];
            }
        }
    }
}
- (void)replaceArray:(NSMutableArray *)array replacekey:(NSString *)replacekey replacevalue:(NSString *)replacevalue {
    for (id valueArrayId in array) {
        if ([valueArrayId isKindOfClass:[NSArray class]]) {
            [self replaceArray:valueArrayId replacekey:replacekey replacevalue:replacevalue];
        } else if ([valueArrayId isKindOfClass:[NSDictionary class]]) {
            [self replaceDict:valueArrayId replacekey:replacekey replacevalue:replacevalue];
        } else if ([valueArrayId isKindOfClass:[NSString class]]) {
            if ([valueArrayId containsString:replacekey]) {
                [array replaceObjectAtIndex:0 withObject:[valueArrayId stringByReplacingOccurrencesOfString:replacekey withString:replacevalue]];
            }
        }
    }
}

///渠道sdk解压
- (void)platformSDKUnzipPlatformModel:(ZCPlatformModel *)platformModel launchImagePath:(NSString *)launchImagePath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    //1.获取渠道文件
    NSString *platformZipPath = [[[ZCFileHelper sharedInstance].PlatformSDKDownloadZip stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", platformModel.alias, platformModel.version]] stringByAppendingPathExtension:@"zip"];
    //移除之前的解压路径
    NSString *platformPath = [[ZCFileHelper sharedInstance].PlatformSDKUnzip stringByAppendingPathComponent:platformModel.alias];
    [manager removeItemAtPath:platformPath error:nil];
    if (logBlock) {
        logBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"正在解压%@", platformModel.platformName]);
    }
    //2.解压
    [[ZCFileHelper sharedInstance] unzip:platformZipPath toPath:[ZCFileHelper sharedInstance].PlatformSDKUnzip complete:^(BOOL result) {
        if (result) {
            
            if (successBlock) {
                successBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"渠道%@解压完成", platformModel.platformName]);
            }
        } else {
            errorBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"渠道%@解压失败", platformModel.platformName]);
        }
        
    }];
}
///渠道文件注入
- (void)platformEditFilesPlatformModel:(ZCPlatformModel *)platformModel launchImagePath:(NSString *)launchImagePath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"复制渠道%@", platformModel.platformName]);
    }
    
    NSString *platformPath = [[ZCFileHelper sharedInstance].PlatformSDKUnzip stringByAppendingPathComponent:platformModel.alias];
    //渠道文件
    NSString *resourcePath = [platformPath stringByAppendingPathComponent:@"resource"];
    
    // 创建队列组，可以使两个网络请求异步执行，执行完之后再进行操作
    dispatch_group_t group = dispatch_group_create();
    
    //任务1
    NSString *platformJsonPath = [[[ZCFileHelper sharedInstance].PlatformSDKJson stringByAppendingPathComponent:platformModel.platformId] stringByAppendingPathExtension:@"json"];
    NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonPath];
    NSString *plat_plist = platformJsonPlist[@"plat_plist"];
    NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:resourcePath error:nil];
    NSString *plat_plistPath;
    for (NSString *file in sourceContents) {
        if ([file isEqualToString:plat_plist]) {
            plat_plistPath = [resourcePath stringByAppendingPathComponent:file];
            break;
        }
    }
    if (plat_plistPath) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 创建信号量
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            NSLog(@"run task 1");
            
            NSMutableDictionary *plat_plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:plat_plistPath];
            NSDictionary *parameter = platformModel.parameter;
            for (NSString *key in parameter.allKeys) {
                if ([plat_plistDict.allKeys containsObject:key]) {
                    [plat_plistDict setObject:parameter[key] forKey:key];
                }
            }
            NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plat_plistDict format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
            if ([xmlData writeToFile:plat_plistPath atomically:YES]) {
                if (logBlock) {
                    logBlock(BlockType_PlatformEditFiles, @"plat_plist修改完成");
                }
                NSLog(@"complete task 1");
                // 无论请求成功或失败都发送信号量(+1)
                dispatch_semaphore_signal(semaphore);
            } else {
                if (logBlock) {
                    logBlock(BlockType_PlatformEditFiles, @"plat_plist写入失败");
                }
                NSLog(@"complete task 1");
                // 无论请求成功或失败都发送信号量(+1)
                dispatch_semaphore_signal(semaphore);
            }
            // 在请求成功之前等待信号量(-1)
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
        });
        
    }
    
    //任务2
    if (sourceContents.count) {
        for (NSString *file in sourceContents) {
            dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 创建信号量
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                NSLog(@"%@", [NSString stringWithFormat:@"run task 2 %@", file]);
                NSString *sourcefilePath = [resourcePath stringByAppendingPathComponent:file];
                NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:file];
                [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                    if (result) {
                        logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", @"resource", file]);
                    } else {
                        errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制失败", @"resource", file]);
                    }
                    NSLog(@"%@", [NSString stringWithFormat:@"complete task 2 %@", file]);
                    // 无论请求成功或失败都发送信号量(+1)
                    dispatch_semaphore_signal(semaphore);
                }];
                // 在请求成功之前等待信号量(-1)
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            });
            
        }
    }
    
    //任务3
    NSString *dylibs = [platformPath stringByAppendingPathComponent:@"dylibs"];
    if ([self->manager fileExistsAtPath:dylibs]) {
        NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:dylibs error:nil];
        if (sourceContents.count) {
            for (NSString *file in sourceContents) {
                dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 创建信号量
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    NSLog(@"%@", [NSString stringWithFormat:@"run task 3 %@", file]);
                    NSString *sourcefilePath = [dylibs stringByAppendingPathComponent:file];
                    NSString *targetfilePath = [[self.appPath stringByAppendingPathComponent:@"Frameworks"] stringByAppendingPathComponent:file];
                    [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                        if (result) {
                            logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", @"dylibs", file]);
                        } else {
                            errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制失败", @"dylibs", file]);
                        }
                        NSLog(@"%@", [NSString stringWithFormat:@"complete task 3 %@", file]);
                        // 无论请求成功或失败都发送信号量(+1)
                        dispatch_semaphore_signal(semaphore);
                    }];
                    // 在请求成功之前等待信号量(-1)
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                });
                
            }
            
        }
    }
    
    //任务4
    NSString *launchimage_ = @"launchimage-";
    if ([platformModel.isLan isEqualToString:@"0"]) {
        launchimage_ = @"launchimage-portrait";
    } else {
        launchimage_ = @"launchimage-landscape";
    }
    NSString *launchimage_Path = [platformPath stringByAppendingPathComponent:launchimage_];
    if ([self->manager fileExistsAtPath:launchimage_Path]) {
        NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:launchimage_Path error:nil];
        if (sourceContents.count) {
            for (NSString *file in sourceContents) {
                dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 创建信号量
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    NSLog(@"%@", [NSString stringWithFormat:@"run task 4 %@", file]);
                    NSString *sourcefilePath = [launchimage_Path stringByAppendingPathComponent:file];
                    NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:file];
                    [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                        if (result) {
                            logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", launchimage_, file]);
                        } else {
                            errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制失败", launchimage_, file]);
                        }
                        NSLog(@"%@", [NSString stringWithFormat:@"complete task 4 %@", file]);
                        // 无论请求成功或失败都发送信号量(+1)
                        dispatch_semaphore_signal(semaphore);
                    }];
                    // 在请求成功之前等待信号量(-1)
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                });
                
            }
            
            //健康公告闪屏
            NSString *platform_bg = nil;
            for (NSString *file in sourceContents) {
                if ([[[file pathExtension] lowercaseString] isEqualToString:@"png"]) {
                    platform_bg = file;
                    break;
                }
            }
            if (!platform_bg && launchImagePath.length) {
                //表示需要设置健康公告为闪屏
                dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 创建信号量
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    NSLog(@"%@", [NSString stringWithFormat:@"run task 4 %@", launchImagePath]);
                    NSString *sourcefilePath = launchImagePath;
                    NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:@"bg.png"];
                    [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                        if (result) {
                            logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", launchimage_, launchImagePath]);
                        } else {
                            errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制失败", launchimage_, launchImagePath]);
                        }
                        NSLog(@"%@", [NSString stringWithFormat:@"complete task 4 %@", launchImagePath]);
                        // 无论请求成功或失败都发送信号量(+1)
                        dispatch_semaphore_signal(semaphore);
                    }];
                    // 在请求成功之前等待信号量(-1)
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                });
            }
            
        }
        
    }
    
    //任务5
    //替换QPJHLightSDK
    NSString *libs = [platformPath stringByAppendingPathComponent:@"libs"];
    NSArray *libsContents = [self->manager contentsOfDirectoryAtPath:libs error:nil];
    NSString *QPJHLightSDKPath;
    NSString *targetQPJHLightSDKPath;
    for (NSString *file in libsContents) {
        if ([[file lastPathComponent] isEqualToString:@"QPJHLightSDK"]) {
            QPJHLightSDKPath = [libs stringByAppendingPathComponent:file];
            targetQPJHLightSDKPath = [[[self.appPath stringByAppendingPathComponent:@"Frameworks"] stringByAppendingPathComponent:@"QPJHLightSDK.framework"] stringByAppendingPathComponent:file];
            break;
        }
    }
    if (QPJHLightSDKPath && targetQPJHLightSDKPath) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 创建信号量
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            NSLog(@"run task 5");
            [[ZCFileHelper sharedInstance] copyFile:QPJHLightSDKPath toPath:targetQPJHLightSDKPath complete:^(BOOL result) {
                if (result) {
                    logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@复制成功", @"QPJHLightSDK"]);
                } else {
                    errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@复制失败", @"QPJHLightSDK"]);
                }
                
                NSLog(@"complete task 5");
                // 无论请求成功或失败都发送信号量(+1)
                dispatch_semaphore_signal(semaphore);
            }];
            // 在请求成功之前等待信号量(-1)
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        });
    }
    
    //任务6
    NSString *AssetsPath = [[ZCFileHelper sharedInstance].GameTemp stringByAppendingPathComponent:@"Assets.xcassets"];
    NSString *appIconSourcePath = [AssetsPath stringByAppendingPathComponent:@"AppIcon.appiconset"];
    NSArray *AppIconsPathContents = [self->manager contentsOfDirectoryAtPath:appIconSourcePath error:nil];

    for (NSString *file in AppIconsPathContents) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 创建信号量
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            NSLog(@"%@", [NSString stringWithFormat:@"run task 6 %@", file]);
            NSString *sourcefilePath = [appIconSourcePath stringByAppendingPathComponent:file];
            
            NSString *localData_plist = [[NSBundle mainBundle] pathForResource:@"ZCLocalData" ofType:@"plist"];
            NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:localData_plist];
            ZCAppIconModel *appIconModel = [ZCAppIconModel mj_objectWithKeyValues:data[@"appicon"]];
            NSString *newFile = nil;
            for (ZCAppIconImageItem *iconImageItem in appIconModel.images) {
                if ([iconImageItem.filename isEqualToString:file]) {
                    NSString *CFBundleIconFilesName = [NSString stringWithFormat:@"AppIcon%@", iconImageItem.size];
                    if ([iconImageItem.idiom isEqualToString:@"iphone"]) {
                        if ([iconImageItem.scale isEqualToString:@"1x"]) {
                            newFile = [NSString stringWithFormat:@"%@", CFBundleIconFilesName];
                        } else if ([iconImageItem.scale isEqualToString:@"2x"]) {
                            newFile = [NSString stringWithFormat:@"%@@2x", CFBundleIconFilesName];
                        } else if ([iconImageItem.scale isEqualToString:@"3x"]) {
                            newFile = [NSString stringWithFormat:@"%@@3x", CFBundleIconFilesName];
                        }
                    }
                    if ([iconImageItem.idiom isEqualToString:@"ipad"]) {
                        if ([iconImageItem.scale isEqualToString:@"1x"]) {
                            newFile = [NSString stringWithFormat:@"%@~ipad", CFBundleIconFilesName];
                        } else if ([iconImageItem.scale isEqualToString:@"2x"]) {
                            newFile = [NSString stringWithFormat:@"%@@2x~ipad", CFBundleIconFilesName];
                        } else if ([iconImageItem.scale isEqualToString:@"3x"]) {
                            newFile = [NSString stringWithFormat:@"%@@3x~ipad", CFBundleIconFilesName];
                        }
                    }
                    break;
                }
            }
            if (newFile) {
                NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:[newFile stringByAppendingPathExtension:@"png"]];
                [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                    if (result) {
                        logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@复制成功", newFile]);
                    } else {
                        errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@复制失败", newFile]);
                    }
                    NSLog(@"%@", [NSString stringWithFormat:@"complete task 6 %@", file]);
                    // 无论请求成功或失败都发送信号量(+1)
                    dispatch_semaphore_signal(semaphore);
                }];
            } else {
                NSLog(@"%@", [NSString stringWithFormat:@"complete task 6 %@", file]);
                // 无论请求成功或失败都发送信号量(+1)
                dispatch_semaphore_signal(semaphore);
            }
            
            // 在请求成功之前等待信号量(-1)
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        });

    }
    
    // 请求完成之后
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (successBlock) {
                successBlock(BlockType_PlatformEditFiles, @"渠道文件修改完成");
            }
        });
    });
    
    
}


#pragma mark - EnbeddedProvision
- (void)editEmbeddedProvision:(ZCProvisioningProfile *)provisoiningProfile  log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_EmbeddedProvision, @"生成Embedded.mobileprovision...");
    }
    
    NSString *payloadPtah = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *payloadContents = [manager contentsOfDirectoryAtPath:payloadPtah error:nil];
    //删除 embedded privisioning
    for (NSString *file in payloadContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            NSString *provisioningPath = [self getEmbeddedProvisioningProfilePath];
            if (provisioningPath) {
                [manager removeItemAtPath:provisioningPath error:nil];
            }
            break;
        }
    }
    
    NSString *targetPath = [[self.appPath stringByAppendingPathComponent:kEmbeddedProvisioningFileName] stringByAppendingPathExtension:@"mobileprovision"];
    [[ZCFileHelper sharedInstance] copyFile:provisoiningProfile.path toPath:targetPath complete:^(BOOL result) {
        if (result) {
            if (successBlock) {
                successBlock(BlockType_EmbeddedProvision, @"Embedded.mobileprovision创建成功");
            }
        } else {
            if (errorBlock) {
                errorBlock(BlockType_EmbeddedProvision, @"创建一个新的Embedded.mobileprovision失败");
            }
        }
    }];
}
- (NSString *)getEmbeddedProvisioningProfilePath {
    NSString *provisioningPtah = nil;
    NSArray *provisioningProfiles = [manager contentsOfDirectoryAtPath:self.appPath error:nil];
    provisioningProfiles = [provisioningProfiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", @[@"mobileprovision", @"provisionprofile"]]];
    for (NSString *path in provisioningProfiles) {
        BOOL isDirectory;
        if ([manager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", self.appPath, path] isDirectory:&isDirectory]) {
            provisioningPtah = [NSString stringWithFormat:@"%@/%@", self.appPath, path];
        }
    }
    return provisioningPtah;
}

#pragma mark - Codesign
- (void)doCodesignCertificateName:(NSString *)certificateName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_DoCodesign, @"签名中...");
    }
    
    if ([manager fileExistsAtPath:self.appPath]) {
        NSMutableArray *waitSignPathArray = @[].mutableCopy;
        NSArray *subpaths = [manager subpathsOfDirectoryAtPath:self.appPath error:nil];
        for (NSString *subpath in subpaths) {
            NSString *extension = [[subpath pathExtension] lowercaseString];
            if ([extension isEqualTo:@"framework"] || [extension isEqualTo:@"dylib"]) {
                [waitSignPathArray addObject:[self.appPath stringByAppendingPathComponent:subpath]];
            }
        }
        
        //最后对appPath也要签名
        [waitSignPathArray addObject:self.appPath];
        
        ZCManuaQueue *queue = [[ZCManuaQueue alloc] init];
        __block NSString *failurePath;
        for (NSString *signPath in waitSignPathArray) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                NSString *entitlementspath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
                
                NSTask *task = [[NSTask alloc] init];
                [task setLaunchPath:@"/usr/bin/codesign"];
                [task setArguments:@[@"-vvv", @"-fs", certificateName, signPath, [NSString stringWithFormat:@"--entitlements=%@", entitlementspath]]];
                
                NSPipe *pipe = [NSPipe pipe];
                [task setStandardOutput:pipe];
                [task setStandardError:pipe];
                NSFileHandle *handle = [pipe fileHandleForReading];
                [task launch];
                [NSThread detachNewThreadSelector:@selector(watchCodesigning:) toTarget:self withObject:handle];
                
                if (logBlock) {
                    logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"开始签名文件：%@", [signPath lastPathComponent]]);
                }
                
                ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
                [runloop run:^{
                    if ([task isRunning] == 0) {
                        [runloop stop:^{
                            //验证签名
                            if (logBlock) {
                                logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"验证文件:%@", [signPath lastPathComponent]]);
                            }
                            [self verifySignature:signPath complete:^(NSString *error) {
                                if (error) {
                                    if (errorBlock) {
                                        failurePath = signPath;
                                        errorBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"签名失败 %@", error]);
                                    }
                                    [queue cancelAll];
                                } else {
                                    if (logBlock) {
                                        logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"文件%@ 签名完成", [signPath lastPathComponent]]);
                                    }
                                    [queue next];
                                }
                            }];
                        }];
                    }
                }];
            }];
            [queue addOperation:operation];
        }
        [queue next];
        queue.noOperationBlock = ^{
            if (successBlock && failurePath == nil) {
                successBlock(BlockType_DoCodesign, @"签名验证完成");
            }
        };
    } else {
        if (errorBlock) {
            errorBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"没有找到文件夹 %@", self.appPath]);
        }
    }
    
    
}
//签名验证
- (void)verifySignature:(NSString *)filePath complete:(void(^)(NSString *error))complete {
    if (self.appPath) {
        
        //验证
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/codesign"];
        [task setArguments:@[@"-v", filePath]];
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        [task setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];
        [task launch];
        [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:) toTarget:self withObject:handle];
        
        ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
        [runloop run:^{
            if ([task isRunning] == 0) {
                [runloop stop:^{
                    if (complete) {
                        if ([self->verificationResult length] == 0) {
                            complete(nil);
                        } else {
                            NSString *error = [[self->codesigningResult stringByAppendingFormat:@"\n\n"] stringByAppendingFormat:@"%@", self->verificationResult];
                            complete(error);
                        }
                    }
                    
                }];
            }
        }];
    }
}
- (void)watchCodesigning:(NSFileHandle *)handle {
    @autoreleasepool {
        codesigningResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}
- (void)watchVerificationProcess:(NSFileHandle *)handle {
    @autoreleasepool {
        verificationResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

#pragma mark - ZipPackage
- (void)zipPackageToDirPath:(NSString *)zipDirPath PlatformModel:(ZCPlatformModel *)platformModel log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *zipIpaName = self.bundleDisplayName;
    if (platformModel) {
        zipIpaName = [NSString stringWithFormat:@"%@_%@_%@", platformModel.gameName, platformModel.alias, [[ZCDateFormatterUtil sharedFormatter] nowForDateFormat:@"yyyyMMddHHmm"]];
    }
    NSString *zipIpaPath = [[zipDirPath stringByAppendingPathComponent:zipIpaName] stringByAppendingPathExtension:@"ipa"];
    
    if (logBlock) {
        logBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@ 开始压缩", zipIpaPath]);
    }
    
    [manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [manager fileExistsAtPath:entitlementsPath]) {
        if (![manager removeItemAtPath:entitlementsPath error:nil]) {
            if (errorBlock) {
                errorBlock(BlockType_Entitlements, @"错误：删除旧Entitlements失败");
            }
            return;
        }
    }
    
    [[ZCFileHelper sharedInstance] zip:self.workPath toPath:zipIpaPath complete:^(BOOL result) {
        if (result) {
            if (successBlock) {
                successBlock(BlockType_ZipPackage, @"文件压缩成功");
            }
        } else {
            if (errorBlock) {
                errorBlock(BlockType_ZipPackage, @"文件压缩失败");
            }
        }
    }];
}

#pragma mark - 渠道出包
- (void)platformbuildresignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certificateName:(NSString *)certificateName platformModels:(NSArray *)platformModels appIconPath:(NSString *)appIconPath launchImagePath:(NSString *)launchImagePath targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    /*
     1.渠道sdk下载
     2.渠道sdk解压
     3.生成AppIcon
     4.创建新的entitlements
     5.修改info.plist
     6.渠道文件注入
     7.修改Embedded Provision
     8.开始签名并验证
     9.压缩文件
     
     */
    
    // 1.创建一个串行队列，保证for循环依次执行
    dispatch_queue_t serialQueue = dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL);
    // 2.异步执行任务
    dispatch_async(serialQueue, ^{
        
        //标记当前时间
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        
        NSMutableArray *successPlatforms = @[].mutableCopy;
        NSMutableArray *errorPlatforms = @[].mutableCopy;
        
        // 3.创建一个数目为1的信号量，用于“卡”for循环，等上次循环结束在执行下一次的for循环
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        for (ZCPlatformModel *platformModel in platformModels) {
            // 开始执行for循环，让信号量-1，这样下次操作须等信号量>=0才会继续,否则下次操作将永久停止
            
            printf("信号量等待中\n");
            if (logBlock) {
                logBlock(BlockType_Unzip, [NSString stringWithFormat:@"%@%@开始打包", platformModel.platformName, platformModel.platformId]);
                logBlock(BlockType_PlatformShow, platformModel.platformName);
            }
            //1.渠道sdk下载
            [[ZCFileHelper sharedInstance] downloadPlatformSDKWithPlatformId:platformModel.platformId log:^(NSString * _Nonnull logString) {
                if (logBlock) {
                    logBlock(BlockType_PlatformSDKDownload, logString);
                }
            } error:^(NSString * _Nonnull errorString) {
                if (errorBlock) {
                    errorBlock(BlockType_PlatformSDKDownload, errorString);
                }
                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                dispatch_semaphore_signal(sema);
            } success:^(id  _Nonnull message) {
                if (successBlock) {
                    successBlock(BlockType_PlatformSDKDownload, message);
                }
                
                //2.渠道sdk解压
                [self platformSDKUnzipPlatformModel:platformModel launchImagePath:launchImagePath log:^(BlockType type, NSString * _Nonnull logString) {
                    if (logBlock) {
                        logBlock(BlockType_PlatformUnzipFiles, logString);
                    }
                } error:^(BlockType type, NSString * _Nonnull errorString) {
                    if (errorBlock) {
                        errorBlock(BlockType_PlatformUnzipFiles, errorString);
                    }
                    // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                    NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                    dispatch_semaphore_signal(sema);
                } success:^(BlockType type, id  _Nonnull message) {
                    if (successBlock) {
                        successBlock(BlockType_PlatformUnzipFiles, message);
                    }
                    
                    //2.生成AppIcon
                    //获取角标
                    NSString *platformPath = [[ZCFileHelper sharedInstance].PlatformSDKUnzip stringByAppendingPathComponent:platformModel.alias];
                    NSString *corner_Path = [platformPath stringByAppendingPathComponent:@"corner"];
                    NSString *marker_path = nil;
                    if ([self->manager fileExistsAtPath:corner_Path]) {
                        NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:corner_Path error:nil];
                        if (sourceContents.count) {
                            for (NSString *file in sourceContents) {
                                if ([[[file pathExtension] lowercaseString] isEqualToString:@"png"]) {
                                    marker_path = [corner_Path stringByAppendingPathComponent:file];
                                    break;
                                }
                            }
                        }
                    }
                    
                    [[ZCFileHelper sharedInstance] getAppIcon:appIconPath markerPath:marker_path toPath:self.appPath log:^(NSString * _Nonnull logString) {
                        if (logBlock) {
                            logBlock(BlockType_PlatformAppIcon, logString);
                        }
                    } error:^(NSString * _Nonnull errorString) {
                        if (errorBlock) {
                            errorBlock(BlockType_PlatformAppIcon, errorString);
                        }
                        // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                        NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                        dispatch_semaphore_signal(sema);
                    } success:^(id  _Nonnull message) {
                        if (successBlock) {
                            successBlock(BlockType_PlatformAppIcon, message);
                        }
                        
                        //3.创建新的entitlements
                        [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                            if (logBlock) {
                                logBlock(BlockType_Entitlements, logString);
                            }
                        } error:^(BlockType type, NSString * _Nonnull errorString) {
                            if (errorBlock) {
                                errorBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@\n%@%@打包失败", errorString, platformModel.platformName, platformModel.platformId]);
                            }
                            [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.platformName, errorString]];
                            // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                            NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                            dispatch_semaphore_signal(sema);
                        } success:^(BlockType type, id  _Nonnull message) {
                            if (successBlock) {
                                successBlock(BlockType_Entitlements, message);
                            }
                            
                            //4.修改info.plist
                            [self platformeditInfoPlistWithPlatformModel:platformModel log:^(BlockType type, NSString * _Nonnull logString) {
                                if (logBlock) {
                                    logBlock(BlockType_InfoPlist, logString);
                                }
                            } error:^(BlockType type, NSString * _Nonnull errorString) {
                                if (errorBlock) {
                                    errorBlock(BlockType_InfoPlist, [NSString stringWithFormat:@"%@\n%@%@打包失败", errorString, platformModel.platformName, platformModel.platformId]);
                                }
                                [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.platformName, errorString]];
                                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                dispatch_semaphore_signal(sema);
                            } success:^(BlockType type, id  _Nonnull message) {
                                if (successBlock) {
                                    successBlock(BlockType_InfoPlist, message);
                                }
                                
                                //5.渠道文件注入
                                [self platformEditFilesPlatformModel:platformModel launchImagePath:launchImagePath log:^(BlockType type, NSString * _Nonnull logString) {
                                    if (logBlock) {
                                        logBlock(BlockType_PlatformEditFiles, logString);
                                    }
                                } error:^(BlockType type, NSString * _Nonnull errorString) {
                                    if (errorBlock) {
                                        errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@\n%@%@打包失败", errorString, platformModel.platformName, platformModel.platformId]);
                                    }
                                    [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.platformName, errorString]];
                                    // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                    NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                    dispatch_semaphore_signal(sema);
                                } success:^(BlockType type, id  _Nonnull message) {
                                    if (successBlock) {
                                        successBlock(BlockType_PlatformEditFiles, message);
                                    }
                                    
                                    //6.修改Embedded Provision
                                    [self editEmbeddedProvision:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                                        if (logBlock) {
                                            logBlock(BlockType_EmbeddedProvision, logString);
                                        }
                                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                                        if (errorBlock) {
                                            errorBlock(BlockType_EmbeddedProvision, [NSString stringWithFormat:@"%@\n%@%@打包失败", errorString, platformModel.platformName, platformModel.platformId]);
                                        }
                                        [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.platformName, errorString]];
                                        // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                        NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                        dispatch_semaphore_signal(sema);
                                    } success:^(BlockType type, id  _Nonnull message) {
                                        if (successBlock) {
                                            successBlock(BlockType_EmbeddedProvision, message);
                                        }
                        
                                        //7.开始签名
                                        [self doCodesignCertificateName:certificateName log:^(BlockType type, NSString * _Nonnull logString) {
                                            if (logBlock) {
                                                logBlock(BlockType_DoCodesign, logString);
                                            }
                                        } error:^(BlockType type, NSString * _Nonnull errorString) {
                                            if (errorBlock) {
                                                errorBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"%@\n%@%@打包失败", errorString, platformModel.platformName, platformModel.platformId]);
                                            }
                                            [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.platformName, errorString]];
                                            // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                            NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                            dispatch_semaphore_signal(sema);
                                        } success:^(BlockType type, id  _Nonnull message) {
                                            if (successBlock) {
                                                successBlock(BlockType_DoCodesign, message);
                                            }
                        
                                            //8.压缩文件
                                            [self zipPackageToDirPath:targetPath PlatformModel:platformModel log:^(BlockType type, NSString * _Nonnull logString) {
                                                if (logBlock) {
                                                    logBlock(BlockType_ZipPackage, logString);
                                                }
                                            } error:^(BlockType type, NSString * _Nonnull errorString) {
                                                if (errorBlock) {
                                                    errorBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@\n%@%@打包失败", errorString, platformModel.platformName, platformModel.platformId]);
                                                }
                                                [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.platformName, errorString]];
                                                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                                dispatch_semaphore_signal(sema);
                                            } success:^(BlockType type, id  _Nonnull message) {
                                                if (successBlock) {
                                                    successBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@\n%@%@打包成功", message, platformModel.platformName, platformModel.platformId]);
                                                }
                                                [successPlatforms addObject:platformModel.platformName];
                                                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                                dispatch_semaphore_signal(sema);
                                            }];
                                        }];
                                    }];
                                }];
                            }];
                        }];
                            
                    }];
                    
                }];
                
            }];
            
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        if (successBlock) {
            
            //再次标记当前时间,计算耗时
            NSTimeInterval currentTime1 = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval diffTime = currentTime1 - currentTime;
            NSString *diffTimeStr = @"";
            long timeHour = 0;
            long timeMinutes = 0;
            long timeSeconds = 0;
            timeHour = diffTime / (60 * 60);
            timeMinutes = (diffTime - timeHour * 60 * 60) / 60;
            timeSeconds = diffTime - timeHour * 60 * 60 - timeMinutes * 60;
            if (timeHour > 24) {
                //时间大于1天，不精确计算
                diffTimeStr = @"大于24小时";
            } else {
                if (timeHour > 1) {
                    diffTimeStr = [NSString stringWithFormat:@"%ld小时", timeHour];
                }
                diffTimeStr = [NSString stringWithFormat:@"%@%ld分", diffTimeStr, timeMinutes];
                if (timeHour || timeMinutes) {
                    diffTimeStr = [NSString stringWithFormat:@"%@%ld秒", diffTimeStr, timeSeconds];
                } else {
                    diffTimeStr = [NSString stringWithFormat:@"%ld秒", timeSeconds];
                }
            }
            
            NSString *successString = [successPlatforms componentsJoinedByString:@"、"];
            NSString *errorString = [errorPlatforms componentsJoinedByString:@"、"];
            successBlock(BlockType_PlatformAllEnd, [NSString stringWithFormat:@"打包结束，耗时%@\n成功(%ld)：%@\n失败(%ld)：%@", diffTimeStr, successPlatforms.count, successString, errorPlatforms.count, errorString]);
        }
        
    });
}

@end
