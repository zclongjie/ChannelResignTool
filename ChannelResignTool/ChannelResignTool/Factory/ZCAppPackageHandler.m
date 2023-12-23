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

@implementation ZCAppPackageHandler {
    NSFileManager *manager;//全局文件管理
    NSString *entitlementsResult;//创建entitlementss任务的结果
    
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
        
        [[ZCFileHelper sharedInstance] copyFiles:self.packagePath toPath:targetPath complete:^(BOOL result) {
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

#pragma mark - resign
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock  error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logResignBlock = [logBlock copy];
    errorResignBlock = [errorBlock copy];
    successResignBlock = [successBlock copy];
    
    /*
     1.创建新的entitlements
     2.修改info.plist
     3.修改Embedded Provision
     4.开始签名
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

- (void)editInfoPlistWithIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) {
        logLocalBlock(@"修改info.plist……");
    }
    
    
}

- (void)editEmbeddedProvision:(ZCProvisioningProfile *)provisoiningProfile  log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    
}

- (void)doCodesignCertificateName:(NSString *)certificateName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    
}

- (void)zipPackageToDirPath:(NSString *)zipDirPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    
}

@end
