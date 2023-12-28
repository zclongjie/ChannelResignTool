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

@implementation ZCAppPackageHandler {
    NSFileManager *manager;//全局文件管理
    NSString *entitlementsResult;//创建entitlementss任务的结果
    NSString *codesigningResult;//签名任务的结果
    NSString *verificationResult;//验证签名任务的结果
    
    LogBlock logResignBlock;
    ErrorBlock errorResignBlock;
    SuccessBlock successResignBlock;
    
    LogBlock logLocalBlock;
    ErrorBlock errorLocalBlock;
    SuccessBlock successLocalBlock;
}

- (instancetype)initWithPackagePath:(NSString *)path {
    self = [super init];
    if (self) {
        manager = [NSFileManager defaultManager];
        
        self.packagePath = path;
        
        //生成临时解压路径（此时目录还未创建）
        NSString *tempPath = CHANNELRESIGNTOOL_PATH;
        NSString *unzipPath = [tempPath stringByAppendingPathComponent:@"unzip"];
        NSString *ipaPathName = [[self.packagePath lastPathComponent] stringByDeletingPathExtension];//从文件的最后一部分删除扩展名
        NSString *ipaPathNamePath = [unzipPath stringByAppendingPathComponent:ipaPathName];
        NSString *dateString = [[ZCDateFormatterUtil sharedFormatter] yyyyMMddHHmmssSSSForDate:[NSDate date]];
        self.workPath = [ipaPathNamePath stringByAppendingPathComponent:dateString];
        
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
//        [manager removeItemAtPath:self.workPath error:nil];
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
//        [manager removeItemAtPath:self.workPath error:nil];
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
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logResignBlock = [logBlock copy];
    errorResignBlock = [errorBlock copy];
    successResignBlock = [successBlock copy];
    
    /*
     1.创建新的entitlements
     2.修改info.plist
     3.修改Embedded Provision
     4.开始签名并验证
     5.压缩文件
     */
    
    //1.创建新的entitlements
    [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
        if (self->logResignBlock) {
            self->logResignBlock(BlockType_Entitlements, logString);
        }
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        if (self->errorResignBlock) {
            self->errorResignBlock(BlockType_Entitlements, errorString);
        }
    } success:^(BlockType type, id  _Nonnull message) {
        if (self->successResignBlock) {
            self->successResignBlock(BlockType_Entitlements, message);
        }
        
        //2.修改info.plist
        [self editInfoPlistWithIdentifier:bundleIdentifier displayName:displayName log:^(BlockType type, NSString * _Nonnull logString) {
            if (self->logResignBlock) {
                self->logResignBlock(BlockType_InfoPlist, logString);
            }
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            if (self->errorResignBlock) {
                self->errorResignBlock(BlockType_InfoPlist, errorString);
            }
        } success:^(BlockType type, id  _Nonnull message) {
            if (self->successResignBlock) {
                self->successResignBlock(BlockType_InfoPlist, message);
            }
            
            //3.修改Embedded Provision
            [self editEmbeddedProvision:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                if (self->logResignBlock) {
                    self->logResignBlock(BlockType_EmbeddedProvision, logString);
                }
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                if (self->errorResignBlock) {
                    self->errorResignBlock(BlockType_EmbeddedProvision, errorString);
                }
            } success:^(BlockType type, id  _Nonnull message) {
                if (self->successResignBlock) {
                    self->successResignBlock(BlockType_EmbeddedProvision, message);
                }
                
                //4.开始签名
                [self doCodesignCertificateName:certificateName log:^(BlockType type, NSString * _Nonnull logString) {
                    if (self->logResignBlock) {
                        self->logResignBlock(BlockType_DoCodesign, logString);
                    }
                } error:^(BlockType type, NSString * _Nonnull errorString) {
                    if (self->errorResignBlock) {
                        self->errorResignBlock(BlockType_DoCodesign, errorString);
                    }
                } success:^(BlockType type, id  _Nonnull message) {
                    if (self->successResignBlock) {
                        self->successResignBlock(BlockType_DoCodesign, message);
                    }
                    
                    //5.压缩文件
                    [self zipPackageToDirPath:targetPath log:^(BlockType type, NSString * _Nonnull logString) {
                        
                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                        if (self->errorResignBlock) {
                            self->errorResignBlock(BlockType_ZipPackage, errorString);
                        }
                    } success:^(BlockType type, id  _Nonnull message) {
                        if (self->successResignBlock) {
                            self->successResignBlock(BlockType_ZipPackage, message);
                        }
                    }];
                    
                }];
            }];
        }];
    }];
}

#pragma mark - Entitlements
- (void)createEntitlementsWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_Entitlements, @"创建Entitlements……");
    }
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [manager fileExistsAtPath:entitlementsPath]) {
        if (![manager removeItemAtPath:entitlementsPath error:nil]) {
            if (errorLocalBlock) {
                errorLocalBlock(BlockType_Entitlements, @"错误：删除旧Entitlements失败");
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
                        NSString *filePath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
                        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlementsDict format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
                        if ([xmlData writeToFile:filePath atomically:YES]) {
                            if (self->successLocalBlock) {
                                self->successLocalBlock(BlockType_Entitlements, @"Entitlements.plist创建成功");
                            }
                        } else {
                            if (self->errorLocalBlock) {
                                self->errorLocalBlock(BlockType_Entitlements, @"Entitlements.plist写入数据失败");
                            }
                        }
                    } else {
                        if (self->errorLocalBlock) {
                            self->errorLocalBlock(BlockType_Entitlements, @"创建Entitlements失败");
                        }
                    }
                }];
            }
        }];
        [NSThread detachNewThreadSelector:@selector(watchEntitlements:) toTarget:self withObject:handle];
    } else {
        if (self->errorLocalBlock) {
            self->errorLocalBlock(BlockType_Entitlements, @"选择的provisioning profile不存在");
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
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_InfoPlist, @"修改info.plist……");
    }
    
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:displayName forKey:kCFBundleDisplayName];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successLocalBlock) {
                successLocalBlock(BlockType_InfoPlist, @"Info.plist修改完成");
            }
        } else {
            if (errorLocalBlock) {
                errorLocalBlock(BlockType_InfoPlist, @"Info.plist写入失败");
            }
        }
    } else {
        if (errorLocalBlock) {
            errorLocalBlock(BlockType_InfoPlist, @"Info.plist未找到");
        }
    }
}

- (void)platformeditInfoPlistWithIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_InfoPlist, @"修改info.plist……");
    }
    
    //todo：这里写死测试，后续网络获取
    NSString *isLan = @"0";//是否横屏
    bundleIdentifier = @"com.swyxios.mly";
    displayName = @"圣物英雄";
    
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:displayName forKey:kCFBundleDisplayName];
        
        [plist setObject:@"LaunchImage" forKey:kUILaunchImageFile];
        [plist setObject:displayName forKey:kUILaunchImages];
        if ([isLan isEqualToString:@"0"]) {
            [plist setObject:@"LaunchPortrait" forKey:kUILaunchStoryboardName];
            [plist setObject:@"LaunchPortrait" forKey:kUILaunchStoryboardNameipad];
            [plist setObject:@"LaunchPortrait" forKey:kUILaunchStoryboardNameiphone];
        } else {
            [plist setObject:@"LaunchLandscape" forKey:kUILaunchStoryboardName];
            [plist setObject:@"LaunchLandscape" forKey:kUILaunchStoryboardNameipad];
            [plist setObject:@"LaunchLandscape" forKey:kUILaunchStoryboardNameiphone];
        }
        
        
        //添加渠道info.plist信息
        //1.获取渠道json文件（实际为网络下载）
        NSString *platformJsonPath = @"/Users/zclongjie/Desktop/tools/1897圣物英雄0.1（米粒游专服）/platformFiles/256.json";
        //2.复制到临时目录
        NSString *platformJsonTargetPath = [[self.workPath stringByAppendingPathComponent:@"256"] stringByAppendingPathExtension:@"json"];
        [[ZCFileHelper sharedInstance] copyFile:platformJsonPath toPath:platformJsonTargetPath complete:^(BOOL result) {
            if (result) {
                NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonTargetPath];
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
            } else {
                if (self->errorLocalBlock) {
                    self->errorLocalBlock(BlockType_InfoPlist, @"复制渠道json文件失败");
                }
            }
        }];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successLocalBlock) {
                successLocalBlock(BlockType_InfoPlist, @"Info.plist修改完成");
            }
        } else {
            if (errorLocalBlock) {
                errorLocalBlock(BlockType_InfoPlist, @"Info.plist写入失败");
            }
        }
    } else {
        if (errorLocalBlock) {
            errorLocalBlock(BlockType_InfoPlist, @"Info.plist未找到");
        }
    }
}

- (void)platformEditFileslog:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_PlatformEditFiles, @"复制渠道文件……");
    }
    
    //todo：这里写死测试，真实需要网络获取
    NSString *isLan = @"0";//是否横屏
    NSDictionary *_256Dict = @{
        @"WANCMS_GAMEID": @"15521",
        @"WANCMS_APPID": @"14881",
        @"WANCMS_AGENT": @"cps001"
    }.copy;
    
    //1.获取渠道文件（实际为网络下载）
    NSString *platformJsonPath = @"/Users/zclongjie/Desktop/tools/1897圣物英雄0.1（米粒游专服）/platformFiles/miliyou_3.4.zip";
    NSString *platformUnzipPath = @"/Users/zclongjie/Desktop/tools/1897圣物英雄0.1（米粒游专服）/platformFiles/platformUnzip";
    //移除之前的解压路径
    [manager removeItemAtPath:platformUnzipPath error:nil];
    //创建新目录
    [manager createDirectoryAtPath:platformUnzipPath withIntermediateDirectories:YES attributes:nil error:nil];
    //2.解压
    [[ZCFileHelper sharedInstance] unzip:platformJsonPath toPath:platformUnzipPath complete:^(BOOL result) {
        if (result) {
            NSString *miliyouPath = [platformUnzipPath stringByAppendingPathComponent:@"miliyou"];
            
            //渠道文件复制
            NSString *resourcePath = [miliyouPath stringByAppendingPathComponent:@"resource"];
            
            //写入渠道参数
            NSString *platformJsonTargetPath = [[self.workPath stringByAppendingPathComponent:@"256"] stringByAppendingPathExtension:@"json"];
            NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonTargetPath];
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
                NSMutableDictionary *plat_plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:plat_plistPath];
                for (NSString *key in _256Dict.allKeys) {
                    if ([plat_plistDict.allKeys containsObject:key]) {
                        [plat_plistDict setObject:_256Dict[key] forKey:key];
                    }
                }
                NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plat_plistDict format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
                if ([xmlData writeToFile:plat_plistPath atomically:YES]) {
                    if (self->logLocalBlock) {
                        self->logLocalBlock(BlockType_PlatformEditFiles, @"plat_plist修改完成");
                    }
                } else {
                    if (self->logLocalBlock) {
                        self->logLocalBlock(BlockType_PlatformEditFiles, @"plat_plist写入失败");
                    }
                }
            }
            
            
            [[ZCFileHelper sharedInstance] copyFiles:resourcePath toPath:self.appPath complete:^(BOOL result) {
                if (result) {
                    self->logLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"resource"]);
                } else {
                    self->errorLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"resource"]);
                }
            }];
            NSString *dylibs = [miliyouPath stringByAppendingPathComponent:@"dylibs"];
            [[ZCFileHelper sharedInstance] copyFiles:dylibs toPath:[self.appPath stringByAppendingPathComponent:@"Frameworks"] complete:^(BOOL result) {
                if (result) {
                    self->logLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"dylibs"]);
                } else {
                    self->errorLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"dylibs"]);
                }
            }];
            if ([isLan isEqualToString:@"0"]) {
                NSString *launchimage_portrait = [miliyouPath stringByAppendingPathComponent:@"launchimage-portrait"];
                [[ZCFileHelper sharedInstance] copyFiles:launchimage_portrait toPath:self.appPath complete:^(BOOL result) {
                    if (result) {
                        self->logLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"launchimage-portrait"]);
                    } else {
                        self->errorLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"launchimage-portrait"]);
                    }
                }];
            } else {
                NSString *launchimage_landscape = [miliyouPath stringByAppendingPathComponent:@"launchimage-landscape"];
                [[ZCFileHelper sharedInstance] copyFiles:launchimage_landscape toPath:self.appPath complete:^(BOOL result) {
                    if (result) {
                        self->logLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"launchimage-landscape"]);
                    } else {
                        self->errorLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"launchimage-landscape"]);
                    }
                }];
            }
            
            //替换QPJHLightSDK
            NSString *libs = [miliyouPath stringByAppendingPathComponent:@"libs"];
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
                [[ZCFileHelper sharedInstance] copyFile:QPJHLightSDKPath toPath:targetQPJHLightSDKPath complete:^(BOOL result) {
                    if (result) {
                        self->logLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件%@复制成功", @"QPJHLightSDK"]);
                    } else {
                        self->errorLocalBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"文件%@复制失败", @"QPJHLightSDK"]);
                    }
                }];
            }
            
        } else {
            errorBlock(BlockType_PlatformEditFiles, @"解压失败");
        }
    }];
    
    if (successLocalBlock) {
        successLocalBlock(BlockType_PlatformEditFiles, @"渠道文件修改完成");
    }
}


#pragma mark - EnbeddedProvision
- (void)editEmbeddedProvision:(ZCProvisioningProfile *)provisoiningProfile  log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_EmbeddedProvision, @"生成Embedded.mobileprovision...");
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
            if (self->successLocalBlock) {
                self->successLocalBlock(BlockType_EmbeddedProvision, @"Embedded.mobileprovision创建成功");
            }
        } else {
            if (self->errorLocalBlock) {
                self->errorLocalBlock(BlockType_EmbeddedProvision, @"创建一个新的Embedded.mobileprovision失败");
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
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_DoCodesign, @"签名中...");
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
                
                if (self->logLocalBlock) {
                    self->logLocalBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"开始签名文件：%@", [signPath lastPathComponent]]);
                }
                
                ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
                [runloop run:^{
                    if ([task isRunning] == 0) {
                        [runloop stop:^{
                            //签名
                            [self verifySignature:signPath complete:^(NSString *error) {
                                if (error) {
                                    if (self->errorLocalBlock) {
                                        failurePath = signPath;
                                        self->errorLocalBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"签名失败 %@", error]);
                                    }
                                    [queue cancelAll];
                                } else {
                                    if (self->logLocalBlock) {
                                        self->logLocalBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"文件%@ 签名完成", [signPath lastPathComponent]]);
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
            if (self->successLocalBlock && failurePath == nil) {
                self->successLocalBlock(BlockType_DoCodesign, @"签名验证完成");
            }
        };
    } else {
        if (errorLocalBlock) {
            errorLocalBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"没有找到文件夹 %@", self.appPath]);
        }
    }
    
    
}
//签名验证
- (void)verifySignature:(NSString *)filePath complete:(void(^)(NSString *error))complete {
    if (self.appPath) {
        if (logLocalBlock) {
            logLocalBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"验证文件:%@", [filePath lastPathComponent]]);
        }
        
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
- (void)zipPackageToDirPath:(NSString *)zipDirPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    NSString *zipIpaPath = [[zipDirPath stringByAppendingPathComponent:self.bundleDisplayName] stringByAppendingPathExtension:@"ipa"];
    
    if (logLocalBlock) {
        logLocalBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@ 开始压缩", zipIpaPath]);
    }
    
    [manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    [[ZCFileHelper sharedInstance] zip:self.workPath toPath:zipIpaPath complete:^(BOOL result) {
        if (result) {
            if (self->successLocalBlock) {
                self->successLocalBlock(BlockType_ZipPackage, @"文件压缩成功");
            }
        } else {
            if (self->errorLocalBlock) {
                self->errorLocalBlock(BlockType_ZipPackage, @"文件压缩失败");
            }
        }
    }];
}

#pragma mark - Xcode自动化出包
- (void)platformbuildresignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logResignBlock = [logBlock copy];
    errorResignBlock = [errorBlock copy];
    successResignBlock = [successBlock copy];
    
    /*
     1.创建新的entitlements
     2.修改info.plist
     3.修改Embedded Provision
     4.开始签名并验证
     5.压缩文件
     */
    
    //1.创建新的entitlements
    [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
        if (self->logResignBlock) {
            self->logResignBlock(BlockType_Entitlements, logString);
        }
    } error:^(BlockType type, NSString * _Nonnull errorString) {
        if (self->errorResignBlock) {
            self->errorResignBlock(BlockType_Entitlements, errorString);
        }
    } success:^(BlockType type, id  _Nonnull message) {
        if (self->successResignBlock) {
            self->successResignBlock(BlockType_Entitlements, message);
        }
        
        //2.修改info.plist
        [self platformeditInfoPlistWithIdentifier:bundleIdentifier displayName:displayName log:^(BlockType type, NSString * _Nonnull logString) {
            if (self->logResignBlock) {
                self->logResignBlock(BlockType_InfoPlist, logString);
            }
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            if (self->errorResignBlock) {
                self->errorResignBlock(BlockType_InfoPlist, errorString);
            }
        } success:^(BlockType type, id  _Nonnull message) {
            if (self->successResignBlock) {
                self->successResignBlock(BlockType_InfoPlist, message);
            }
            
            //
            [self platformEditFileslog:^(BlockType type, NSString * _Nonnull logString) {
                if (self->logResignBlock) {
                    self->logResignBlock(BlockType_PlatformEditFiles, logString);
                }
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                if (self->errorResignBlock) {
                    self->errorResignBlock(BlockType_PlatformEditFiles, errorString);
                }
            } success:^(BlockType type, id  _Nonnull message) {
                if (self->successResignBlock) {
                    self->successResignBlock(BlockType_PlatformEditFiles, message);
                }
                
                //3.修改Embedded Provision
                [self editEmbeddedProvision:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                    if (self->logResignBlock) {
                        self->logResignBlock(BlockType_EmbeddedProvision, logString);
                    }
                } error:^(BlockType type, NSString * _Nonnull errorString) {
                    if (self->errorResignBlock) {
                        self->errorResignBlock(BlockType_EmbeddedProvision, errorString);
                    }
                } success:^(BlockType type, id  _Nonnull message) {
                    if (self->successResignBlock) {
                        self->successResignBlock(BlockType_EmbeddedProvision, message);
                    }
    
                    //4.开始签名
                    [self doCodesignCertificateName:certificateName log:^(BlockType type, NSString * _Nonnull logString) {
                        if (self->logResignBlock) {
                            self->logResignBlock(BlockType_DoCodesign, logString);
                        }
                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                        if (self->errorResignBlock) {
                            self->errorResignBlock(BlockType_DoCodesign, errorString);
                        }
                    } success:^(BlockType type, id  _Nonnull message) {
                        if (self->successResignBlock) {
                            self->successResignBlock(BlockType_DoCodesign, message);
                        }
    
                        //5.压缩文件
                        [self zipPackageToDirPath:targetPath log:^(BlockType type, NSString * _Nonnull logString) {
                            if (self->logResignBlock) {
                                self->logResignBlock(BlockType_ZipPackage, logString);
                            }
                        } error:^(BlockType type, NSString * _Nonnull errorString) {
                            if (self->errorResignBlock) {
                                self->errorResignBlock(BlockType_ZipPackage, errorString);
                            }
                        } success:^(BlockType type, id  _Nonnull message) {
                            if (self->successResignBlock) {
                                self->successResignBlock(BlockType_ZipPackage, message);
                            }
                        }];
                    }];
                }];
            }];
            

        }];
    }];
}

@end
