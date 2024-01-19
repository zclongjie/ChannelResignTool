//
//  ZCFileHelper.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define CHANNELRESIGNTOOL_PATH [NSHomeDirectory() stringByAppendingPathComponent:[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleExecutableKey]]

//typedef NS_ENUM(NSInteger, FileHelperBlockType)
//{
//    FileHelperBlockType_Unzip = 0,
//    BlockType_Entitlements,
//    BlockType_InfoPlist,
//    BlockType_EmbeddedProvision,
//    BlockType_DoCodesign,
//    BlockType_ZipPackage,
//    BlockType_PlatformEditFiles,
//    BlockType_PlatformShow,
//    BlockType_PlatformAllEnd
//};

typedef void(^FileHelperSuccessBlock)(id message);
typedef void(^FileHelperErrorBlock)(NSString *errorString);
typedef void(^FileHelperLogBlock)(NSString *logString);


@interface ZCFileHelper : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)lackSupportUtility;
///获取签名证书
- (void)getCertificatesLog:(void (^)(NSString *log))logBlock error:(void (^)(NSString *error))errorBlock success:(void (^)(NSArray *certificateNames))successBlock;
///获取配置文件
- (NSArray *)getProvisioningProfiles;

///app文件空间
- (void)appSpace;

///复制文件
- (void)copyFile:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL result))completeBlock;
///复制多个文件
//- (void)copyFiles:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL result))completeBlock;

///解压
- (void)unzip:(NSString *)sourcePath toPath:(NSString *)targetPath complete:(void (^)(BOOL result))completeBlock;
///压缩
- (void)zip:(NSString *)sourcepath toPath:(NSString *)targetPath complete:(void (^)(BOOL result))completeBlock;

///生成AppIcon
- (void)getAppIcon:(NSString *)sourcePath toPath:(NSString *)targetPath log:(FileHelperLogBlock)logBlock error:(FileHelperErrorBlock)errorBlock success:(FileHelperSuccessBlock)successBlock;

@end

NS_ASSUME_NONNULL_END
