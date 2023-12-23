//
//  ZCFileHelper.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define TEMP_PATH [NSTemporaryDirectory() stringByAppendingPathComponent:@"resign"]

@interface ZCFileHelper : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)lackSupportUtility;
///获取签名证书
- (void)getCertificatesSuccess:(void (^)(NSArray *certificateNames))successBlock error:(void (^)(NSString *error))errorBlock;
///获取配置文件
- (NSArray *)getProvisioningProfiles;

///复制文件
- (void)copyFiles:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL result))completeBlock;

///解压
- (void)unzip:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL result))completeBlock;

@end

NS_ASSUME_NONNULL_END
