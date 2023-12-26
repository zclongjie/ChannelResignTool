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
        NSString *tempPath = TEMP_PATH;
        NSString *unzipPath = [tempPath stringByAppendingPathComponent:@"unzip"];
        NSString *ipaPathName = [[self.packagePath lastPathComponent] stringByDeletingPathExtension];//从文件的最后一部分删除扩展名
        NSString *ipaPathNamePath = [unzipPath stringByAppendingPathComponent:ipaPathName];
        NSString *dateString = [[ZCDateFormatterUtil sharedFormatter] timestampForDate:[NSDate date]];
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
- (void)unzipIpa:(void (^)(void))successBlock error:(void (^)(NSString * _Nonnull))errorBlock {
    if ([self.packagePath.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
        
        //移除之前的解压路径
        [manager removeItemAtPath:self.workPath error:nil];
        //创建新目录
        [manager createDirectoryAtPath:self.workPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        //解压
        [[ZCFileHelper sharedInstance] unzip:self.packagePath toPath:self.workPath complete:^(BOOL result) {
            if (result) {
                [self setAppPath];
                if (successBlock) {
                    successBlock();
                } else {
                    errorBlock(@"解压失败");
                }
            } else {
                errorBlock(@"解压失败");
            }
        }];
        
    } else if ([self.packagePath.pathExtension.lowercaseString isEqualToString:@"app"]) {
        
        //移除之前的解压路径
        [manager removeItemAtPath:self.workPath error:nil];
        //创建新目录
        NSString *payloadPath = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
        [manager createDirectoryAtPath:payloadPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *targetPath = [payloadPath stringByAppendingPathComponent:self.packagePath.lastPathComponent];
        
        [[ZCFileHelper sharedInstance] copyFile:self.packagePath toPath:targetPath complete:^(BOOL result) {
            if (result) {
                [self setAppPath];
                if (successBlock) {
                    successBlock();
                } else {
                    errorBlock(@"文件复制失败");
                }
            } else {
                errorBlock(@"文件复制失败");
            }
        }];
        
    } else {
        if (errorBlock) {
            errorBlock([NSString stringWithFormat:@"文件扩展名不是ipa或app"]);
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
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock  error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
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
    [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(NSString * _Nonnull logString) {
        if (self->logResignBlock) {
            self->logResignBlock(logString);
        }
    } error:^(NSString * _Nonnull errorString) {
        if (self->errorResignBlock) {
            self->errorResignBlock(errorString);
        }
    } success:^(id  _Nonnull message) {
        if (self->successResignBlock) {
            self->successResignBlock(message);
        }
        
        //2.修改info.plist
        [self editInfoPlistWithIdentifier:bundleIdentifier displayName:displayName log:^(NSString * _Nonnull logString) {
            if (self->logResignBlock) {
                self->logResignBlock(logString);
            }
        } error:^(NSString * _Nonnull errorString) {
            if (self->errorResignBlock) {
                self->errorResignBlock(errorString);
            }
        } success:^(id  _Nonnull message) {
            if (self->successResignBlock) {
                self->successResignBlock(message);
            }
            
            //3.修改Embedded Provision
            [self editEmbeddedProvision:provisioningProfile log:^(NSString * _Nonnull logString) {
                if (self->logResignBlock) {
                    self->logResignBlock(logString);
                }
            } error:^(NSString * _Nonnull errorString) {
                if (self->errorResignBlock) {
                    self->errorResignBlock(errorString);
                }
            } success:^(id  _Nonnull message) {
                if (self->successResignBlock) {
                    self->successResignBlock(message);
                }
                
                //4.开始签名
                [self doCodesignCertificateName:certificateName log:^(NSString * _Nonnull logString) {
                    if (self->logResignBlock) {
                        self->logResignBlock(logString);
                    }
                } error:^(NSString * _Nonnull errorString) {
                    if (self->errorResignBlock) {
                        self->errorResignBlock(errorString);
                    }
                } success:^(id  _Nonnull message) {
                    if (self->successResignBlock) {
                        self->successResignBlock(message);
                    }
                    
                    //5.压缩文件
                    [self zipPackageToDirPath:targetPath log:^(NSString * _Nonnull logString) {
                        if (self->logResignBlock) {
                            self->logResignBlock(logString);
                        }
                    } error:^(NSString * _Nonnull errorString) {
                        if (self->errorResignBlock) {
                            self->errorResignBlock(errorString);
                        }
                    } success:^(id  _Nonnull message) {
                        if (self->successResignBlock) {
                            self->successResignBlock(message);
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
        logLocalBlock(@"创建Entitlements……");
    }
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [manager fileExistsAtPath:entitlementsPath]) {
        if (![manager removeItemAtPath:entitlementsPath error:nil]) {
            if (errorLocalBlock) {
                errorLocalBlock(@"错误：删除旧Entitlements失败");
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
                                self->successLocalBlock(@"Entitlements.plist创建成功");
                            }
                        } else {
                            if (self->errorLocalBlock) {
                                self->errorLocalBlock(@"Entitlements.plist写入数据失败");
                            }
                        }
                    } else {
                        if (self->errorLocalBlock) {
                            self->errorLocalBlock(@"创建Entitlements失败");
                        }
                    }
                }];
            }
        }];
        [NSThread detachNewThreadSelector:@selector(watchEntitlements:) toTarget:self withObject:handle];
    } else {
        if (self->errorLocalBlock) {
            self->errorLocalBlock(@"选择的provisioning profile不存在");
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
        logLocalBlock(@"修改info.plist……");
    }
    
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:displayName forKey:kCFBundleDisplayName];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successLocalBlock) {
                successLocalBlock(@"Info.plist修改完成");
            }
        } else {
            if (errorLocalBlock) {
                errorLocalBlock(@"Info.plist写入失败");
            }
        }
    } else {
        if (errorLocalBlock) {
            errorLocalBlock(@"Info.plist未找到");
        }
    }
}

- (void)platformeditInfoPlistWithIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(@"修改info.plist……");
    }
    
    //todo：这里写死测试，后续网络获取
    bundleIdentifier = @"com.swyxios.mly";
    displayName = @"圣物英雄";
    
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:displayName forKey:kCFBundleDisplayName];
        
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
                    self->errorLocalBlock(@"复制渠道json文件失败");
                }
            }
        }];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successLocalBlock) {
                successLocalBlock(@"Info.plist修改完成");
            }
        } else {
            if (errorLocalBlock) {
                errorLocalBlock(@"Info.plist写入失败");
            }
        }
    } else {
        if (errorLocalBlock) {
            errorLocalBlock(@"Info.plist未找到");
        }
    }
}

- (void)platformeditFileslog:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(@"复制渠道文件……");
    }
    
    //todo：这里写死测试，后续网络获取
    NSString *appID = @"14881";
    NSString *gameID = @"15521";
    NSString *isLan = @"0";//是否横屏
    
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
            [[ZCFileHelper sharedInstance] copyFiles:resourcePath toPath:self.appPath complete:^(BOOL result) {
                if (result) {
                    self->logLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"resource"]);
                } else {
                    self->errorLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"resource"]);
                }
            }];
            NSString *dylibs = [miliyouPath stringByAppendingPathComponent:@"dylibs"];
            [[ZCFileHelper sharedInstance] copyFiles:dylibs toPath:[self.appPath stringByAppendingPathComponent:@"Frameworks"] complete:^(BOOL result) {
                if (result) {
                    self->logLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"dylibs"]);
                } else {
                    self->errorLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"dylibs"]);
                }
            }];
            if ([isLan isEqualToString:@"0"]) {
                NSString *launchimage_portrait = [miliyouPath stringByAppendingPathComponent:@"launchimage-portrait"];
                [[ZCFileHelper sharedInstance] copyFiles:launchimage_portrait toPath:self.appPath complete:^(BOOL result) {
                    if (result) {
                        self->logLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"launchimage-portrait"]);
                    } else {
                        self->errorLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"launchimage-portrait"]);
                    }
                }];
            } else {
                NSString *launchimage_landscape = [miliyouPath stringByAppendingPathComponent:@"launchimage-landscape"];
                [[ZCFileHelper sharedInstance] copyFiles:launchimage_landscape toPath:self.appPath complete:^(BOOL result) {
                    if (result) {
                        self->logLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制成功", @"launchimage-landscape"]);
                    } else {
                        self->errorLocalBlock([NSString stringWithFormat:@"文件夹%@内的文件复制失败", @"launchimage-landscape"]);
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
                        self->logLocalBlock([NSString stringWithFormat:@"文件%@复制成功", @"QPJHLightSDK"]);
                    } else {
                        self->errorLocalBlock([NSString stringWithFormat:@"文件%@复制失败", @"QPJHLightSDK"]);
                    }
                }];
            }
            
        } else {
            errorBlock(@"解压失败");
        }
    }];
    
    
}


#pragma mark - EnbeddedProvision
- (void)editEmbeddedProvision:(ZCProvisioningProfile *)provisoiningProfile  log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(@"生成Embedded.mobileprovision...");
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
                self->successLocalBlock(@"Embedded.mobileprovision创建成功");
            }
        } else {
            if (self->errorLocalBlock) {
                self->errorLocalBlock(@"创建一个新的Embedded.mobileprovision失败");
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
        logLocalBlock(@"签名中...");
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
                    self->logLocalBlock([NSString stringWithFormat:@"开始签名文件：%@", [signPath lastPathComponent]]);
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
                                        self->errorLocalBlock([NSString stringWithFormat:@"签名失败 %@", error]);
                                    }
                                    [queue cancelAll];
                                } else {
                                    if (self->successLocalBlock) {
                                        self->successLocalBlock([NSString stringWithFormat:@"文件%@ 签名完成", [signPath lastPathComponent]]);
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
                self->successLocalBlock(@"签名验证完成");
            }
        };
    } else {
        if (errorLocalBlock) {
            errorLocalBlock([NSString stringWithFormat:@"没有找到文件夹 %@", self.appPath]);
        }
    }
    
    
}
//签名验证
- (void)verifySignature:(NSString *)filePath complete:(void(^)(NSString *error))complete {
    if (self.appPath) {
        if (logLocalBlock) {
            logLocalBlock([NSString stringWithFormat:@"验证文件:%@", [filePath lastPathComponent]]);
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
        logLocalBlock([NSString stringWithFormat:@"%@ 开始压缩", zipIpaPath]);
    }
    
    [manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    [[ZCFileHelper sharedInstance] zip:self.workPath toPath:zipIpaPath complete:^(BOOL result) {
        if (result) {
            if (self->successLocalBlock) {
                self->successLocalBlock(@"文件压缩成功\n完成签名");
            }
        } else {
            if (self->errorLocalBlock) {
                self->errorLocalBlock(@"文件压缩失败");
            }
        }
    }];
}

#pragma mark - Xcode自动化出包
- (void)platformbuildresignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock  error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
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
    [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(NSString * _Nonnull logString) {
        if (self->logResignBlock) {
            self->logResignBlock(logString);
        }
    } error:^(NSString * _Nonnull errorString) {
        if (self->errorResignBlock) {
            self->errorResignBlock(errorString);
        }
    } success:^(id  _Nonnull message) {
        if (self->successResignBlock) {
            self->successResignBlock(message);
        }
        
        //2.修改info.plist
        [self platformeditInfoPlistWithIdentifier:bundleIdentifier displayName:displayName log:^(NSString * _Nonnull logString) {
            if (self->logResignBlock) {
                self->logResignBlock(logString);
            }
        } error:^(NSString * _Nonnull errorString) {
            if (self->errorResignBlock) {
                self->errorResignBlock(errorString);
            }
        } success:^(id  _Nonnull message) {
            if (self->successResignBlock) {
                self->successResignBlock(message);
            }
            
            //
            [self platformeditFileslog:^(NSString * _Nonnull logString) {
                if (self->logResignBlock) {
                    self->logResignBlock(logString);
                }
            } error:^(NSString * _Nonnull errorString) {
                if (self->errorResignBlock) {
                    self->errorResignBlock(errorString);
                }
            } success:^(id  _Nonnull message) {
                if (self->successResignBlock) {
                    self->successResignBlock(message);
                }
                
                
            }];
            
//            //3.修改Embedded Provision
//            [self editEmbeddedProvision:provisioningProfile log:^(NSString * _Nonnull logString) {
//                if (self->logResignBlock) {
//                    self->logResignBlock(logString);
//                }
//            } error:^(NSString * _Nonnull errorString) {
//                if (self->errorResignBlock) {
//                    self->errorResignBlock(errorString);
//                }
//            } success:^(id  _Nonnull message) {
//                if (self->successResignBlock) {
//                    self->successResignBlock(message);
//                }
//
//                //4.开始签名
//                [self doCodesignCertificateName:certificateName log:^(NSString * _Nonnull logString) {
//                    if (self->logResignBlock) {
//                        self->logResignBlock(logString);
//                    }
//                } error:^(NSString * _Nonnull errorString) {
//                    if (self->errorResignBlock) {
//                        self->errorResignBlock(errorString);
//                    }
//                } success:^(id  _Nonnull message) {
//                    if (self->successResignBlock) {
//                        self->successResignBlock(message);
//                    }
//
//                    //5.压缩文件
//                    [self zipPackageToDirPath:targetPath log:^(NSString * _Nonnull logString) {
//                        if (self->logResignBlock) {
//                            self->logResignBlock(logString);
//                        }
//                    } error:^(NSString * _Nonnull errorString) {
//                        if (self->errorResignBlock) {
//                            self->errorResignBlock(errorString);
//                        }
//                    } success:^(id  _Nonnull message) {
//                        if (self->successResignBlock) {
//                            self->successResignBlock(message);
//                        }
//                    }];
//                }];
//            }];
        }];
    }];
}

@end
