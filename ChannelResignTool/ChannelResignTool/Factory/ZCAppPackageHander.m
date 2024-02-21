//
//  ZCAppPackageHander.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import "ZCAppPackageHander.h"
#import "ZCFileHelper.h"
#import "ZCRunLoop.h"
#import "ZCManuaQueue.h"
#import "ZCAppIconModel.h"
#import "ZCDataUtil.h"
#import "ZCDateFormatterUtil.h"
#import "ZCProvisioningProfile.h"

@interface ZCAppPackageHander ()

@property (nonatomic, copy) NSString *entitlementsResult;//创建entitlementss任务的结果
@property (nonatomic, copy) NSString *codesigningResult;//签名任务的结果
@property (nonatomic, copy) NSString *verificationResult;//验证签名任务的结果

///包的路径
@property (nonatomic, copy) NSString *packagePath;

@end

@implementation ZCAppPackageHander

#pragma mark ----------通用实现----------

- (instancetype)initWithPackagePath:(NSString *)path {
    self = [super init];
    if (self) {
        self.manager = [NSFileManager defaultManager];
        
        self.packagePath = path;
        
        //生成临时解压路径（此时目录还未创建）
        NSString *ipaPathName = [[self.packagePath lastPathComponent] stringByDeletingPathExtension];//从文件的最后一部分删除扩展名
        self.temp_workPath = [[ZCFileHelper sharedInstance].GameTemp stringByAppendingPathComponent:[NSString stringWithFormat:@"temp_%@",ipaPathName]];
        
    }
    return self;
}

- (BOOL)removeCodeSignatureDirectory {
    NSString *codeSignaturePath = [self.appPath stringByAppendingPathComponent:kCodeSignatureDirectory];
    if (codeSignaturePath && [self.manager fileExistsAtPath:codeSignaturePath]) {
        return [self.manager removeItemAtPath:codeSignaturePath error:nil];
    } else if (![self.manager fileExistsAtPath:codeSignaturePath]) {
        return YES;
    }
    return NO;
}

#pragma mark - unzip
- (void)unzipIpaLog:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    if ([self.packagePath.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
        
        //移除之前的解压路径
        if ([self.manager fileExistsAtPath:self.temp_workPath]) {
            [self.manager removeItemAtPath:self.temp_workPath error:nil];
        }
        //创建新目录
        [self.manager createDirectoryAtPath:self.temp_workPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        //解压
        [[ZCFileHelper sharedInstance] unzip:self.packagePath toPath:self.temp_workPath complete:^(BOOL result) {
            if (result) {
                
                [self setupAppInfo];
                if (successBlock) {
                    successBlock(BlockType_Unzip, @"文件解压完成");
                }
            } else {
                errorBlock(BlockType_Unzip, @"文件解压失败");
            }
        }];
        
    } else if ([self.packagePath.pathExtension.lowercaseString isEqualToString:@"app"]) {
        
        //移除之前的解压路径
        if ([self.manager fileExistsAtPath:self.temp_workPath]) {
            [self.manager removeItemAtPath:self.temp_workPath error:nil];
        }
        //创建新目录
        NSString *temp_payloadPath = [self.temp_workPath stringByAppendingPathComponent:kPayloadDirName];
        [self.manager createDirectoryAtPath:temp_payloadPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *targetPath = [temp_payloadPath stringByAppendingPathComponent:self.packagePath.lastPathComponent];
        
        [[ZCFileHelper sharedInstance] copyFile:self.packagePath toPath:targetPath complete:^(BOOL result) {
            if (result) {
                [self setupAppInfo];
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
- (void)setupAppInfo {
    //gameId
    NSString *temp_payloadPath = [self.temp_workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *temp_payloadContents = [self.manager contentsOfDirectoryAtPath:temp_payloadPath error:nil];
    [temp_payloadContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *file = (NSString *)obj;
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            NSString *tem_appPath = [[self.temp_workPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            //QPJHPLIST.plist
            NSString *QPJHPLISTFilePath = [tem_appPath stringByAppendingPathComponent:kQPJHPLISTFileName];
            NSMutableDictionary *QPJHPlistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:QPJHPLISTFilePath];
            if ([QPJHPlistDict.allKeys containsObject:@"game_id"]) {
                NSString *game_id = [QPJHPlistDict objectForKey:@"game_id"];
                self.gameId = game_id.integerValue;
            }

            //Info.plist
            NSString *infoPlistPath = [tem_appPath stringByAppendingPathComponent:kInfoPlistFileName];
            NSMutableDictionary *infoPlistDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
            if ([infoPlistDict.allKeys containsObject:kCFBundleIdentifier]) {
                self.bundleIdentifier = infoPlistDict[kCFBundleIdentifier];
            }
            if ([infoPlistDict.allKeys containsObject:kCFBundleDisplayName]) {
                self.bundleDisplayName = infoPlistDict[kCFBundleDisplayName];
            }
            if ([infoPlistDict.allKeys containsObject:kCFBundleName]) {
                self.bundleName = infoPlistDict[kCFBundleName];
            }
            
            *stop = YES;
        }
    }];
}

- (void)temp_workPathToWorkPath {
        
    //创建新目录
    self.workPath = [[ZCFileHelper sharedInstance].GameTemp stringByAppendingPathComponent:@(self.gameId).stringValue];
    [self.manager createDirectoryAtPath:self.workPath withIntermediateDirectories:YES attributes:nil error:nil];
    [[ZCFileHelper sharedInstance] copyFile:self.temp_workPath toPath:self.workPath complete:^(BOOL result) {
        if (result) {
            [self setAppPath];
        }
    }];
}

- (void)setAppPath {
    NSString *payloadPath = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *payloadContents = [self.manager contentsOfDirectoryAtPath:payloadPath error:nil];
    [payloadContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *file = (NSString *)obj;
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            self.appPath = [[self.workPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            *stop = YES;
        }
    }];
}


#pragma mark - Entitlements
- (void)createEntitlementsWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [self.manager fileExistsAtPath:entitlementsPath]) {
        if (![self.manager removeItemAtPath:entitlementsPath error:nil]) {
            if (errorBlock) {
                errorBlock(BlockType_Entitlements, @"错误：删除旧Entitlements失败");
            }
            return;
        }
    }
    
    //使用provisioningProfile作为新的Entitlements
    if ([self.manager fileExistsAtPath:provisioningProfile.path]) {
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
                        if ([self.entitlementsResult respondsToSelector:@selector(containsString:)] && [self.entitlementsResult containsString:@"SecPolicySetValue"]) {
                            NSMutableArray *linesInOutput = [self.entitlementsResult componentsSeparatedByString:@"\n"].mutableCopy;
                            [linesInOutput removeObjectAtIndex:0];
                            self.entitlementsResult = [linesInOutput componentsJoinedByString:@"\n"];
                        }
                        NSMutableDictionary *entitlementsDict = [[NSMutableDictionary alloc] initWithDictionary:self.entitlementsResult.propertyList[@"Entitlements"]];
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
        self.entitlementsResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

#pragma mark - EnbeddedProvision
- (void)editEmbeddedProvision:(ZCProvisioningProfile *)provisoiningProfile  log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *payloadPtah = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *payloadContents = [self.manager contentsOfDirectoryAtPath:payloadPtah error:nil];
    //删除 embedded privisioning
    for (NSString *file in payloadContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            NSString *provisioningPath = [self getEmbeddedProvisioningProfilePath];
            if (provisioningPath) {
                [self.manager removeItemAtPath:provisioningPath error:nil];
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
    NSArray *provisioningProfiles = [self.manager contentsOfDirectoryAtPath:self.appPath error:nil];
    provisioningProfiles = [provisioningProfiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", @[@"mobileprovision", @"provisionprofile"]]];
    for (NSString *path in provisioningProfiles) {
        BOOL isDirectory;
        if ([self.manager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", self.appPath, path] isDirectory:&isDirectory]) {
            provisioningPtah = [NSString stringWithFormat:@"%@/%@", self.appPath, path];
        }
    }
    return provisioningPtah;
}

#pragma mark - Codesign
- (void)doCodesignCertificateName:(NSString *)certificateName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    if ([self.manager fileExistsAtPath:self.appPath]) {
        NSMutableArray *waitSignPathArray = @[].mutableCopy;
        NSArray *subpaths = [self.manager subpathsOfDirectoryAtPath:self.appPath error:nil];
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
//                    logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"开始签名文件：%@", [signPath lastPathComponent]]);
                }
                
                ZCRunLoop *runloop = [[ZCRunLoop alloc] init];
                [runloop run:^{
                    if ([task isRunning] == 0) {
                        [runloop stop:^{
                            //验证签名
                            if (logBlock) {
//                                logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"验证文件:%@", [signPath lastPathComponent]]);
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
//                                        logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"文件%@ 签名完成", [signPath lastPathComponent]]);
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
                        if ([self.verificationResult length] == 0) {
                            complete(nil);
                        } else {
                            NSString *error = [[self.codesigningResult stringByAppendingFormat:@"\n\n"] stringByAppendingFormat:@"%@", self.verificationResult];
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
        self.codesigningResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}
- (void)watchVerificationProcess:(NSFileHandle *)handle {
    @autoreleasepool {
        self.verificationResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

#pragma mark ----------母包签名实现----------
#pragma mark - Info.plist
- (void)editInfoPlistWithIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([self.manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        if (bundleIdentifier) {
            [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
            self.bundleIdentifier = bundleIdentifier;
        }
        if (displayName) {
            [plist setObject:displayName forKey:kCFBundleDisplayName];
            self.bundleDisplayName = displayName;
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

#pragma mark - ZipPackage
- (void)zipPackageToDirPath:(NSString *)zipDirPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *zipIpaName = @(self.gameId).stringValue;
    if (self.bundleDisplayName) {
        zipIpaName = self.bundleDisplayName;
    } else if (self.bundleName) {
        zipIpaName = self.bundleName;
    } else if (self.bundleIdentifier) {
        zipIpaName = self.bundleIdentifier;
    }

    NSString *zipIpaPath = [[zipDirPath stringByAppendingPathComponent:zipIpaName] stringByAppendingPathExtension:@"ipa"];
    
    if (logBlock) {
        logBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@ 开始压缩", zipIpaPath]);
    }
    
    [self.manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [self.manager fileExistsAtPath:entitlementsPath]) {
        if (![self.manager removeItemAtPath:entitlementsPath error:nil]) {
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

#pragma mark - Resign
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certificateName:(NSString *)certificateName useMobileprovisionBundleID:(BOOL)useMobileprovisionBundleID bundleIdField_str:(NSString *)bundleIdField_str appNameField_str:(NSString *)appNameField_str targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    //标记当前时间
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (logBlock) {
        logBlock(BlockType_Unzip, [NSString stringWithFormat:@"开始重签"]);
    }
    
    //copy到workPath
    [self temp_workPathToWorkPath];
    
    NSString *bundleIdentifier = @"";
    if (useMobileprovisionBundleID) {
        bundleIdentifier = provisioningProfile.bundleIdentifier;
    } else {
        if ([bundleIdField_str length] == 0) {
            bundleIdentifier = self.bundleIdentifier;
        } else {
            bundleIdentifier = bundleIdField_str;
        }
    }
    NSString *displayName = @"";
    if ([appNameField_str length] == 0) {
        displayName = self.bundleDisplayName;
    } else {
        displayName = appNameField_str;
    }
    [self removeCodeSignatureDirectory];
    
    /*
     1.创建新的entitlements
     2.修改info.plist
     3.修改Embedded Provision
     4.开始签名并验证
     5.压缩文件
     */
    
    //1.创建新的entitlements
    if (logBlock) {
        logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"开始创建新的entitlements"]);
    }
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
        if (logBlock) {
            logBlock(BlockType_InfoPlist, [NSString stringWithFormat:@"修改info.plist"]);
        }
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
            if (logBlock) {
                logBlock(BlockType_EmbeddedProvision, [NSString stringWithFormat:@"修改Embedded Provision"]);
            }
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
                if (logBlock) {
                    logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"开始签名"]);
                }
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
                    if (logBlock) {
                        logBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"压缩文件"]);
                    }
                    [self zipPackageToDirPath:targetPath log:^(BlockType type, NSString * _Nonnull logString) {
                        if (logBlock) {
                            logBlock(BlockType_DoCodesign, logString);
                        }
                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                        if (errorBlock) {
                            errorBlock(BlockType_ZipPackage, errorString);
                        }
                    } success:^(BlockType type, id  _Nonnull message) {
                        if (successBlock) {
                            successBlock(BlockType_ZipPackage, message);
                            //打包完成移除解压文件
                            if ([self.manager fileExistsAtPath:self.workPath]) {
                                [self.manager removeItemAtPath:self.workPath error:nil];
                            }
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
                            
                            successBlock(BlockType_PlatformAllEnd, [NSString stringWithFormat:@"重签成功，耗时%@", diffTimeStr]);
                        }
                        
                        
                    }];
                    
                }];
            }];
        }];
    }];
}


#pragma mark ----------渠道出包实现----------
#pragma mark - Info.plist
- (void)platformeditInfoPlistWithArgument:(NSDictionary *)argument channelId:(NSInteger)channelId log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *ios_package = [argument objectForKey:@"ios_package"];
    NSString *screen_type = [argument objectForKey:@"screen_type"];//2为竖屏
    NSString *plat_game_name = [argument objectForKey:@"plat_game_name"];
        
    NSString *infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFileName];
    if ([self.manager fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        if (ios_package) {
            [plist setObject:ios_package forKey:kCFBundleIdentifier];
        }
        if (plat_game_name) {
            [plist setObject:plat_game_name forKey:kCFBundleDisplayName];
        }
        
        [plist setObject:@"LaunchImage" forKey:kUILaunchImageFile];
        
        if ([screen_type isEqualToString:@"2"]) {
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
        //1.获取渠道json文件
        NSString *platformJsonPath = [[[ZCFileHelper sharedInstance].PlatformSDKJson stringByAppendingPathComponent:@(channelId).stringValue] stringByAppendingPathExtension:@"json"];
        NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonPath];
        //替换参数值 如{package}
        [self gamePlistInjectValue:platformJsonPlist platformArgument:argument];
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
                errorBlock(BlockType_InfoPlist, @"Info.plist修改失败");
            }
        }
    } else {
        if (errorBlock) {
            errorBlock(BlockType_InfoPlist, @"Info.plist未找到");
        }
    }
}
- (void)gamePlistInjectValue:(NSMutableDictionary *)platformJsonPlist platformArgument:(NSDictionary *)argument {
    NSMutableDictionary *game_plist = platformJsonPlist[@"game_plist"];
    NSMutableDictionary *replace = platformJsonPlist[@"replace"];
    for (NSString *replacekey in replace.allKeys) {
        NSString *replacevalue = nil;
        if ([replace[replacekey] isEqualToString:@"package"]) {
            replacevalue = [argument objectForKey:@"ios_package"];
        } else {
            replacevalue = [argument objectForKey:replace[replacekey]];
        }
        if (replacevalue) {
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
}
- (void)replaceDict:(NSMutableDictionary *)dict replacekey:(NSString *)replacekey replacevalue:(NSString *)replacevalue {
    NSMutableDictionary *tempDict = [dict mutableCopy];
    for (NSString *key in tempDict.allKeys) {
        id valueDictId = tempDict[key];
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
    NSMutableArray *tempArray = [array mutableCopy];
    for (id valueArrayId in tempArray) {
        if ([valueArrayId isKindOfClass:[NSArray class]]) {
            [self replaceArray:valueArrayId replacekey:replacekey replacevalue:replacevalue];
        } else if ([valueArrayId isKindOfClass:[NSDictionary class]]) {
            [self replaceDict:valueArrayId replacekey:replacekey replacevalue:replacevalue];
        } else if ([valueArrayId isKindOfClass:[NSString class]]) {
            if ([valueArrayId containsString:replacekey]) {
                [array replaceObjectAtIndex:[tempArray indexOfObject:valueArrayId] withObject:[valueArrayId stringByReplacingOccurrencesOfString:replacekey withString:replacevalue]];
            }
        }
    }
}

///渠道sdk解压
- (void)platformSDKUnzipPlatformModel:(ZCPlatformDataJsonModel *)platformModel launchImagePath:(NSString *)launchImagePath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    //判断PlatformSDKUnzip是否存在，存在则不需要解压
    NSString *PlatformSDKUnzip = [ZCFileHelper sharedInstance].PlatformSDKUnzip;
    NSArray *PlatformSDKUnzipContents = [self.manager contentsOfDirectoryAtPath:PlatformSDKUnzip error:nil];
    NSString *location_channel_unzip = nil;
    if (PlatformSDKUnzipContents.count) {
        for (NSString *file in PlatformSDKUnzipContents) {
            if ([file hasPrefix:platformModel.alias]) {
                location_channel_unzip = file;
                break;
            }
        }
    }
    if (location_channel_unzip) {
        if (successBlock) {
            successBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"渠道%@无需解压", platformModel.name]);
        }
    } else {
        //1.获取渠道文件
        NSString *PlatformSDKDownloadZip = [ZCFileHelper sharedInstance].PlatformSDKDownloadZip;
        NSArray *PlatformSDKDownloadZipContents = [self.manager contentsOfDirectoryAtPath:PlatformSDKDownloadZip error:nil];
        NSString *location_channel_zip = nil;
        if (PlatformSDKDownloadZipContents.count) {
            for (NSString *file in PlatformSDKDownloadZipContents) {
                if ([file hasPrefix:platformModel.alias]) {
                    location_channel_zip = file;
                    break;
                }
            }
        }
        if (location_channel_zip) {
            if (logBlock) {
                logBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"正在解压%@", platformModel.name]);
            }
            //2.解压
            NSString *location_channel_zip_path = [PlatformSDKDownloadZip stringByAppendingPathComponent:location_channel_zip];
            [[ZCFileHelper sharedInstance] unzip:location_channel_zip_path toPath:[ZCFileHelper sharedInstance].PlatformSDKUnzip complete:^(BOOL result) {
                if (result) {
                    
                    if (successBlock) {
                        successBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"渠道%@解压完成", platformModel.name]);
                    }
                } else {
                    errorBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"渠道%@解压失败", platformModel.name]);
                }
                
            }];
        }
    }
        
}
///渠道文件注入
- (void)platformEditFilesPlatformModel:(ZCPlatformDataJsonModel *)platformModel argument:(NSDictionary *)argument launchImagePath:(NSString *)launchImagePath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *platformPath = [[ZCFileHelper sharedInstance].PlatformSDKUnzip stringByAppendingPathComponent:platformModel.alias];
    //渠道资源文件
    NSString *resource_Path = [platformPath stringByAppendingPathComponent:@"resource"];
    //渠道动态库文件
    NSString *dylibs_Path = [platformPath stringByAppendingPathComponent:@"dylibs"];
    //渠道闪屏文件
    NSString *launchimage_ = @"launchimage-";
    NSString *screen_type = [argument objectForKey:@"screen_type"];//2为竖屏
    if (!screen_type) {
        launchimage_ = @"launchimage-portrait";
    }
    if ([screen_type isEqualToString:@"2"]) {
        launchimage_ = @"launchimage-portrait";
    } else {
        launchimage_ = @"launchimage-landscape";
    }
    NSString *launchimage_Path = [platformPath stringByAppendingPathComponent:launchimage_];
    //奇葩动态库文件
    NSString *libs_Path = [platformPath stringByAppendingPathComponent:@"libs"];

    // 创建队列组，可以使两个网络请求异步执行，执行完之后再进行操作
    dispatch_group_t group = dispatch_group_create();
    
    //任务1 渠道plist文件参数修改和resource复制
    if ([self.manager fileExistsAtPath:resource_Path]) {
        NSString *platformJsonPath = [[[ZCFileHelper sharedInstance].PlatformSDKJson stringByAppendingPathComponent:@(platformModel.id_).stringValue] stringByAppendingPathExtension:@"json"];
        NSMutableDictionary *platformJsonPlist = [[ZCDataUtil shareInstance] readJsonFile:platformJsonPath];
        NSString *plat_plist = platformJsonPlist[@"plat_plist"];
        NSArray *sourceContents = [self.manager contentsOfDirectoryAtPath:resource_Path error:nil];
        NSString *plat_plistPath;
        for (NSString *file in sourceContents) {
            if ([file isEqualToString:plat_plist]) {
                plat_plistPath = [resource_Path stringByAppendingPathComponent:file];
                break;
            }
        }
        if (plat_plistPath) {
            NSMutableDictionary *plat_plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:plat_plistPath];
            for (NSString *key in argument.allKeys) {
                if ([plat_plistDict.allKeys containsObject:key]) {
                    [plat_plistDict setObject:argument[key] forKey:key];
                }
            }
            NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plat_plistDict format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
            if ([xmlData writeToFile:plat_plistPath atomically:YES]) {
                //plat_plist写入成功
                for (NSString *file in sourceContents) {
                    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        // 创建信号量
                        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        NSLog(@"%@", [NSString stringWithFormat:@"run task 2 %@", file]);
                        NSString *sourcefilePath = [resource_Path stringByAppendingPathComponent:file];
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
            } else {
                if (errorBlock) {
                    errorBlock(BlockType_PlatformEditFiles, @"plat_plist写入失败");
                }
            }
        }
    }
    
    //任务2 dylibs复制
    if ([self.manager fileExistsAtPath:dylibs_Path]) {
        NSArray *dylibsContents = [self.manager contentsOfDirectoryAtPath:dylibs_Path error:nil];
        if (dylibsContents.count) {
            for (NSString *file in dylibsContents) {
                dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 创建信号量
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    NSLog(@"%@", [NSString stringWithFormat:@"run task 3 %@", file]);
                    NSString *sourcefilePath = [dylibs_Path stringByAppendingPathComponent:file];
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
    
    //任务3 launchimage复制
    if ([self.manager fileExistsAtPath:launchimage_Path]) {
        NSArray *launchimageContents = [self.manager contentsOfDirectoryAtPath:launchimage_Path error:nil];
        if (launchimageContents.count) {
            for (NSString *file in launchimageContents) {
                dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 创建信号量
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    NSLog(@"%@", [NSString stringWithFormat:@"run task 4 %@", file]);
                    NSString *sourcefilePath = [launchimage_Path stringByAppendingPathComponent:file];
                    NSString *targetfilePath = [self.appPath stringByAppendingPathComponent:file];
                    [[ZCFileHelper sharedInstance] copyFile:sourcefilePath toPath:targetfilePath complete:^(BOOL result) {
                        if (result) {
//                            logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@-%@复制成功", launchimage_, file]);
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
            for (NSString *file in launchimageContents) {
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
    
    //任务4 替换QPJHLightSDK
    if ([self.manager fileExistsAtPath:libs_Path]) {
        NSArray *libsContents = [self.manager contentsOfDirectoryAtPath:libs_Path error:nil];
        NSString *QPJHLightSDKPath;
        NSString *targetQPJHLightSDKPath;
        for (NSString *file in libsContents) {
            if ([[file lastPathComponent] isEqualToString:@"QPJHLightSDK"]) {
                QPJHLightSDKPath = [libs_Path stringByAppendingPathComponent:file];
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
    }
    
    //任务5
    NSString *AssetsPath = [[ZCFileHelper sharedInstance].GameTemp stringByAppendingPathComponent:@"Assets.xcassets"];
    NSString *appIconSourcePath = [AssetsPath stringByAppendingPathComponent:@"AppIcon.appiconset"];
    if ([self.manager fileExistsAtPath:appIconSourcePath]) {
        NSArray *AppIconsPathContents = [self.manager contentsOfDirectoryAtPath:appIconSourcePath error:nil];

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
    //                        logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@复制成功", newFile]);
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

#pragma mark - ZipPackage
- (void)zipPackageToDirPath:(NSString *)zipDirPath platformModel:(ZCPlatformDataJsonModel *)platformModel argument:(NSDictionary *)argument log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    NSString *zipIpaName = @"";//ipa重签
    if (argument) {
        NSString *plat_game_name = [argument objectForKey:@"plat_game_name"];
        if (!plat_game_name) {
            plat_game_name = zipIpaName;
        }
        zipIpaName = [NSString stringWithFormat:@"%ld%@_%@_%@", (long)self.gameId, plat_game_name, platformModel.alias, [[ZCDateFormatterUtil sharedFormatter] nowForDateFormat:@"yyyyMMddHHmm"]];
    }

    NSString *zipIpaPath = [[zipDirPath stringByAppendingPathComponent:zipIpaName] stringByAppendingPathExtension:@"ipa"];
    
    if (logBlock) {
        logBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@ 开始压缩", zipIpaPath]);
    }
    
    [self.manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    //先检查是否存在entitlements，存在先删掉
    NSString *entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFileName];
    if (entitlementsPath && [self.manager fileExistsAtPath:entitlementsPath]) {
        if (![self.manager removeItemAtPath:entitlementsPath error:nil]) {
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
        
        for (ZCPlatformDataJsonModel *platformModel in platformModels) {
            // 开始执行for循环，让信号量-1，这样下次操作须等信号量>=0才会继续,否则下次操作将永久停止
            
            printf("信号量等待中\n");
            if (logBlock) {
                logBlock(BlockType_Unzip, [NSString stringWithFormat:@"%@[%ld]开始打包", platformModel.name, (long)platformModel.id_]);
                logBlock(BlockType_PlatformShow, platformModel.name);
            }
            
            //copy到workPath
            [self temp_workPathToWorkPath];
            
            //1.渠道sdk下载
            if (logBlock) {
                logBlock(BlockType_PlatformSDKDownload, [NSString stringWithFormat:@"%@[%ld]渠道sdk下载", platformModel.name, (long)platformModel.id_]);
            }
            [[ZCFileHelper sharedInstance] downloadPlatformSDKByGameId:self.gameId ByPlatformModel:platformModel log:^(NSString * _Nonnull logString) {
                if (logBlock) {
                    logBlock(BlockType_PlatformSDKDownload, logString);
                }
            } error:^(NSString * _Nonnull errorString) {
                if (errorBlock) {
                    errorBlock(BlockType_PlatformSDKDownload, errorString);
                }
                [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                dispatch_semaphore_signal(sema);
            } success:^(id  _Nonnull message) {
                if (successBlock) {
                    successBlock(BlockType_PlatformSDKDownload, [NSString stringWithFormat:@"渠道%@下载成功", platformModel.name]);
                }
                
                NSDictionary *game_channel_argument = (NSDictionary *)message;
                
                //2.渠道sdk解压
                if (logBlock) {
                    logBlock(BlockType_PlatformUnzipFiles, [NSString stringWithFormat:@"%@[%ld]渠道sdk解压", platformModel.name, (long)platformModel.id_]);
                }
                [self platformSDKUnzipPlatformModel:platformModel launchImagePath:launchImagePath log:^(BlockType type, NSString * _Nonnull logString) {
                    if (logBlock) {
                        logBlock(BlockType_PlatformUnzipFiles, logString);
                    }
                } error:^(BlockType type, NSString * _Nonnull errorString) {
                    if (errorBlock) {
                        errorBlock(BlockType_PlatformUnzipFiles, errorString);
                    }
                    [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                    // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                    NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                    dispatch_semaphore_signal(sema);
                } success:^(BlockType type, id  _Nonnull message) {
                    if (successBlock) {
                        successBlock(BlockType_PlatformUnzipFiles, message);
                    }
                    
                    //2.生成AppIcon
                    if (logBlock) {
                        logBlock(BlockType_PlatformAppIcon, [NSString stringWithFormat:@"开始生成AppIcon"]);
                    }
                    //获取角标
                    NSString *platformPath = [[ZCFileHelper sharedInstance].PlatformSDKUnzip stringByAppendingPathComponent:platformModel.alias];
                    NSString *corner_Path = [platformPath stringByAppendingPathComponent:@"corner"];
                    NSString *marker_path = nil;
                    if ([self.manager fileExistsAtPath:corner_Path]) {
                        NSArray *sourceContents = [self.manager contentsOfDirectoryAtPath:corner_Path error:nil];
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
                        [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                        // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                        NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                        dispatch_semaphore_signal(sema);
                    } success:^(id  _Nonnull message) {
                        if (successBlock) {
                            successBlock(BlockType_PlatformAppIcon, message);
                        }
                        
                        //3.创建新的entitlements
                        if (logBlock) {
                            logBlock(BlockType_Entitlements, [NSString stringWithFormat:@"开始创建新的entitlements"]);
                        }
                        [self createEntitlementsWithProvisioningProfile:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                            if (logBlock) {
                                logBlock(BlockType_Entitlements, logString);
                            }
                        } error:^(BlockType type, NSString * _Nonnull errorString) {
                            if (errorBlock) {
                                errorBlock(BlockType_Entitlements, [NSString stringWithFormat:@"%@", errorString]);
                            }
                            [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                            // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                            NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                            dispatch_semaphore_signal(sema);
                        } success:^(BlockType type, id  _Nonnull message) {
                            if (successBlock) {
                                successBlock(BlockType_Entitlements, message);
                            }
                            
                            //4.修改info.plist
                            if (logBlock) {
                                logBlock(BlockType_InfoPlist, [NSString stringWithFormat:@"修改info.plist"]);
                            }
                            [self platformeditInfoPlistWithArgument:game_channel_argument channelId:platformModel.id_ log:^(BlockType type, NSString * _Nonnull logString) {
                                if (logBlock) {
                                    logBlock(BlockType_InfoPlist, logString);
                                }
                            } error:^(BlockType type, NSString * _Nonnull errorString) {
                                if (errorBlock) {
                                    errorBlock(BlockType_InfoPlist, [NSString stringWithFormat:@"%@", errorString]);
                                }
                                [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                dispatch_semaphore_signal(sema);
                            } success:^(BlockType type, id  _Nonnull message) {
                                if (successBlock) {
                                    successBlock(BlockType_InfoPlist, message);
                                }
                                
                                //5.渠道文件注入
                                if (logBlock) {
                                    logBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"渠道文件注入"]);
                                }
                                [self platformEditFilesPlatformModel:platformModel argument:game_channel_argument launchImagePath:launchImagePath log:^(BlockType type, NSString * _Nonnull logString) {
                                    if (logBlock) {
                                        logBlock(BlockType_PlatformEditFiles, logString);
                                    }
                                } error:^(BlockType type, NSString * _Nonnull errorString) {
                                    if (errorBlock) {
                                        errorBlock(BlockType_PlatformEditFiles, [NSString stringWithFormat:@"%@", errorString]);
                                    }
                                    [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                                    // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                    NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                    dispatch_semaphore_signal(sema);
                                } success:^(BlockType type, id  _Nonnull message) {
                                    if (successBlock) {
                                        successBlock(BlockType_PlatformEditFiles, message);
                                    }
                                    
                                    //6.修改Embedded Provision
                                    if (logBlock) {
                                        logBlock(BlockType_EmbeddedProvision, [NSString stringWithFormat:@"修改Embedded Provision"]);
                                    }
                                    [self editEmbeddedProvision:provisioningProfile log:^(BlockType type, NSString * _Nonnull logString) {
                                        if (logBlock) {
                                            logBlock(BlockType_EmbeddedProvision, logString);
                                        }
                                    } error:^(BlockType type, NSString * _Nonnull errorString) {
                                        if (errorBlock) {
                                            errorBlock(BlockType_EmbeddedProvision, [NSString stringWithFormat:@"%@", errorString]);
                                        }
                                        [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                                        // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                        NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                        dispatch_semaphore_signal(sema);
                                    } success:^(BlockType type, id  _Nonnull message) {
                                        if (successBlock) {
                                            successBlock(BlockType_EmbeddedProvision, message);
                                        }
                        
                                        //7.开始签名
                                        if (logBlock) {
                                            logBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"开始签名"]);
                                        }
                                        [self doCodesignCertificateName:certificateName log:^(BlockType type, NSString * _Nonnull logString) {
                                            if (logBlock) {
                                                logBlock(BlockType_DoCodesign, logString);
                                            }
                                        } error:^(BlockType type, NSString * _Nonnull errorString) {
                                            if (errorBlock) {
                                                errorBlock(BlockType_DoCodesign, [NSString stringWithFormat:@"%@", errorString]);
                                            }
                                            [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                                            // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                            NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                            dispatch_semaphore_signal(sema);
                                        } success:^(BlockType type, id  _Nonnull message) {
                                            if (successBlock) {
                                                successBlock(BlockType_DoCodesign, message);
                                            }
                        
                                            //8.压缩文件
                                            if (logBlock) {
                                                logBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"压缩文件"]);
                                            }
                                            [self zipPackageToDirPath:targetPath platformModel:platformModel argument:game_channel_argument log:^(BlockType type, NSString * _Nonnull logString) {
                                                if (logBlock) {
                                                    logBlock(BlockType_ZipPackage, logString);
                                                }
                                            } error:^(BlockType type, NSString * _Nonnull errorString) {
                                                if (errorBlock) {
                                                    errorBlock(BlockType_ZipPackage, [NSString stringWithFormat:@"%@", errorString]);
                                                }
                                                [errorPlatforms addObject:[NSString stringWithFormat:@"%@(%@)", platformModel.name, errorString]];
                                                // 本次for循环的异步任务执行完毕，这时候要发一个信号，若不发，下次操作将永远不会触发
                                                NSLog(@"本次耗时操作完成，信号量+1 %@\n",[NSThread currentThread]);
                                                dispatch_semaphore_signal(sema);
                                            } success:^(BlockType type, id  _Nonnull message) {
                                                if (successBlock) {
                                                    successBlock(BlockType_ZipPackage, message);
                                                }
                                                [successPlatforms addObject:platformModel.name];
                                                
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
            //打包完成移除解压文件
            if ([self.manager fileExistsAtPath:self.workPath]) {
                [self.manager removeItemAtPath:self.workPath error:nil];
            }
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
            
            NSString *successString = [successPlatforms componentsJoinedByString:@"，"];
            NSString *errorString = [errorPlatforms componentsJoinedByString:@"，"];
            successBlock(BlockType_PlatformAllEnd, [NSString stringWithFormat:@"打包结束，耗时%@\n成功(%ld)：%@\n失败(%ld)：%@", diffTimeStr, successPlatforms.count, successString, errorPlatforms.count, errorString]);
        }
        
    });
}

@end
