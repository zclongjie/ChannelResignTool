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
}

- (instancetype)initWithPackagePath:(NSString *)path {
    self = [super init];
    if (self) {
        manager = [NSFileManager defaultManager];
        
        self.packagePath = path;
        
        //生成临时解压路径（此时目录还未创建）
        NSString *unzipPath = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"GameUnzip"];
        NSString *ipaPathName = [[self.packagePath lastPathComponent] stringByDeletingPathExtension];//从文件的最后一部分删除扩展名
        self.workPath = [unzipPath stringByAppendingPathComponent:ipaPathName];
        
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
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
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
//        [plist setObject:displayName forKey:kUILaunchImages];
        if ([platformModel.isLan isEqualToString:@"0"]) {
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
        NSString *platformJsonPath = [[[CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"ChannelData"] stringByAppendingPathComponent:platformModel.platformId] stringByAppendingPathExtension:@"json"];
        NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonPath];
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

- (void)platformEditFilesPlatformModel:(ZCPlatformModel *)platformModel log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if (logBlock) {
        logBlock(BlockType_PlatformEditFiles, @"复制渠道文件……");
    }
    
    //1.获取渠道文件（实际为网络下载）
    NSString *platformJsonPath = [[[CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"DownSdk"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", platformModel.alias, platformModel.version]] stringByAppendingPathExtension:@"zip"];
    NSString *platformUnzipPath = [CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"PlatformUnzip"];
    //移除之前的解压路径
    NSString *miliyouPath = [platformUnzipPath stringByAppendingPathComponent:platformModel.alias];
    [manager removeItemAtPath:miliyouPath error:nil];
    //2.解压
    [[ZCFileHelper sharedInstance] unzip:platformJsonPath toPath:platformUnzipPath complete:^(BOOL result) {
        if (result) {
            if (logBlock) {
                logBlock(BlockType_PlatformEditFiles, @"渠道文件复制完成");
            }
            //渠道文件复制
            NSString *resourcePath = [miliyouPath stringByAppendingPathComponent:@"resource"];
            
            // 创建队列组，可以使两个网络请求异步执行，执行完之后再进行操作
            dispatch_group_t group = dispatch_group_create();
            
            //写入渠道参数
            NSString *platformJsonPath = [[[CHANNELRESIGNTOOL_PATH stringByAppendingPathComponent:@"ChannelData"] stringByAppendingPathComponent:platformModel.platformId] stringByAppendingPathExtension:@"json"];
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
            NSString *dylibs = [miliyouPath stringByAppendingPathComponent:@"dylibs"];
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
            if ([platformModel.isLan isEqualToString:@"0"]) {
                NSString *launchimage_portrait = [miliyouPath stringByAppendingPathComponent:@"launchimage-portrait"];
                if ([self->manager fileExistsAtPath:launchimage_portrait]) {
                    NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:launchimage_portrait error:nil];
                    if (sourceContents.count) {
                        for (NSString *file in sourceContents) {
                            dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                // 创建信号量
                                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                                NSLog(@"%@", [NSString stringWithFormat:@"run task 4 %@", file]);
                                NSString *sourcefilePath = [launchimage_portrait stringByAppendingPathComponent:file];
                                NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:file];
                                [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                                    if (result) {
                                        logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", @"launchimage-portrait", file]);
                                    } else {
                                        errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制失败", @"launchimage-portrait", file]);
                                    }
                                    NSLog(@"%@", [NSString stringWithFormat:@"complete task 4 %@", file]);
                                    // 无论请求成功或失败都发送信号量(+1)
                                    dispatch_semaphore_signal(semaphore);
                                }];
                                // 在请求成功之前等待信号量(-1)
                                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                            });
                            
                        }
                        
                    }
                }
                
                
            } else {
                NSString *launchimage_landscape = [miliyouPath stringByAppendingPathComponent:@"launchimage-landscape"];
                if ([self->manager fileExistsAtPath:launchimage_landscape]) {
                    NSArray *sourceContents = [self->manager contentsOfDirectoryAtPath:launchimage_landscape error:nil];
                    if (sourceContents.count) {
                        for (NSString *file in sourceContents) {
                            dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                // 创建信号量
                                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                                NSLog(@"%@", [NSString stringWithFormat:@"run task 4 %@", file]);
                                NSString *sourcefilePath = [launchimage_landscape stringByAppendingPathComponent:file];
                                NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:file];
                                [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                                    if (result) {
                                        logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", @"launchimage-landscape", file]);
                                    } else {
                                        errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制失败", @"launchimage-landscape", file]);
                                    }
                                    NSLog(@"%@", [NSString stringWithFormat:@"complete task 4 %@", file]);
                                    // 无论请求成功或失败都发送信号量(+1)
                                    dispatch_semaphore_signal(semaphore);
                                }];
                                // 在请求成功之前等待信号量(-1)
                                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                            });
                            
                        }
                        
                    }
                }
                
            }
            
            //任务5
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
            
            
            
            // 请求完成之后
            dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (successBlock) {
                        successBlock(BlockType_PlatformEditFiles, @"渠道文件修改完成");
                    }
                });
            });
            
        } else {
            errorBlock(BlockType_PlatformEditFiles, @"解压失败");
        }
        
        
    }];
    
    
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
        zipIpaName = [NSString stringWithFormat:@"%@_%@_%@", platformModel.gameName, platformModel.alias, [[ZCDateFormatterUtil sharedFormatter] nowForDateFormat:@"yyyyMMddHHmmss"]];
    }
    NSString *zipIpaPath = [[zipDirPath stringByAppendingPathComponent:zipIpaName] stringByAppendingPathExtension:@"ipa"];
    
    if (logBlock) {
        logBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@ 开始压缩", zipIpaPath]);
    }
    
    [manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
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

#pragma mark - Xcode自动化出包
- (void)platformbuildresignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName platformModels:(NSArray *)platformModels targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    /*
     1.创建新的entitlements
     2.修改info.plist
     3.修改Embedded Provision
     4.开始签名并验证
     5.压缩文件
     */
    
    dispatch_group_t group = dispatch_group_create();
    
    for (ZCPlatformModel *platformModel in platformModels) {
        if (logBlock) {
            logBlock(BlockType_Unzip, [NSString stringWithFormat:@"%@%@开始打包", platformModel.platformName, platformModel.platformId]);
        }
        dispatch_group_enter(group);
        //1.创建新的entitlements
        [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
            if (logBlock) {
                logBlock(BlockType_Entitlements, logString);
            }
        } error:^(BlockType type, NSString * _Nonnull errorString) {
            if (logBlock) {
                logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包失败", platformModel.platformName, platformModel.platformId]);
            }
            if (errorBlock) {
                errorBlock(BlockType_Entitlements, errorString);
            }
            dispatch_group_leave(group);
        } success:^(BlockType type, id  _Nonnull message) {
            if (successBlock) {
                successBlock(BlockType_Entitlements, message);
            }
            
            //2.修改info.plist
            [self platformeditInfoPlistWithPlatformModel:platformModel log:^(BlockType type, NSString * _Nonnull logString) {
                if (logBlock) {
                    logBlock(BlockType_InfoPlist, logString);
                }
            } error:^(BlockType type, NSString * _Nonnull errorString) {
                if (logBlock) {
                    logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包失败", platformModel.platformName, platformModel.platformId]);
                }
                if (errorBlock) {
                    errorBlock(BlockType_InfoPlist, errorString);
                }
                dispatch_group_leave(group);
            } success:^(BlockType type, id  _Nonnull message) {
                if (successBlock) {
                    successBlock(BlockType_InfoPlist, message);
                }
                
                //
                [self platformEditFilesPlatformModel:platformModel log:^(BlockType type, NSString * _Nonnull logString) {
                    if (logBlock) {
                        logBlock(BlockType_PlatformEditFiles, logString);
                    }
                } error:^(BlockType type, NSString * _Nonnull errorString) {
                    if (logBlock) {
                        logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包失败", platformModel.platformName, platformModel.platformId]);
                    }
                    if (errorBlock) {
                        errorBlock(BlockType_PlatformEditFiles, errorString);
                    }
                    dispatch_group_leave(group);
                } success:^(BlockType type, id  _Nonnull message) {
                    if (successBlock) {
                        successBlock(BlockType_PlatformEditFiles, message);
                    }
                    
                    //3.修改Embedded Provision
                    [self editEmbeddedProvision:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                        if (logBlock) {
                            logBlock(BlockType_EmbeddedProvision, logString);
                        }
                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                        if (logBlock) {
                            logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包失败", platformModel.platformName, platformModel.platformId]);
                        }
                        if (errorBlock) {
                            errorBlock(BlockType_EmbeddedProvision, errorString);
                        }
                        dispatch_group_leave(group);
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
                            if (logBlock) {
                                logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包失败", platformModel.platformName, platformModel.platformId]);
                            }
                            if (errorBlock) {
                                errorBlock(BlockType_DoCodesign, errorString);
                            }
                            dispatch_group_leave(group);
                        } success:^(BlockType type, id  _Nonnull message) {
                            if (successBlock) {
                                successBlock(BlockType_DoCodesign, message);
                            }
        
                            //5.压缩文件
                            [self zipPackageToDirPath:targetPath PlatformModel:platformModel log:^(BlockType type, NSString * _Nonnull logString) {
                                if (logBlock) {
                                    logBlock(BlockType_ZipPackage, logString);
                                }
                            } error:^(BlockType type, NSString * _Nonnull errorString) {
                                if (errorBlock) {
                                    errorBlock(BlockType_ZipPackage, errorString);
                                }
                                if (logBlock) {
                                    logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包失败", platformModel.platformName, platformModel.platformId]);
                                }
                                dispatch_group_leave(group);
                            } success:^(BlockType type, id  _Nonnull message) {
                                if (successBlock) {
                                    successBlock(BlockType_ZipPackage, message);
                                }
                                if (logBlock) {
                                    logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@%@打包成功", platformModel.platformName, platformModel.platformId]);
                                }
                                dispatch_group_leave(group);
                            }];
                        }];
                    }];
                }];
            }];
            
        }];
        
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(0, 0), ^{
        NSLog(@"全部执行完成");
        if (successBlock) {
            successBlock(BlockType_PlatformAllEnd, @"所有渠道打包完成End");
        }
    });
    
}

@end
