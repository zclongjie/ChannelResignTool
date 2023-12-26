//
//  ZCAppPackageHandler.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import <Foundation/Foundation.h>
#import "ZCProvisioningProfile.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *kPayloadDirName = @"Payload";
static NSString *kInfoPlistFileName = @"Info.plist";
static NSString *kCFBundleDisplayName = @"CFBundleDisplayName";
static NSString *kCFBundleIdentifier = @"CFBundleIdentifier";
static NSString *kCodeSignatureDirectory = @"_CodeSignature";
static NSString *kEntitlementsPlistFileName = @"Entitlements.plist";
static NSString *kEmbeddedProvisioningFileName  = @"embedded";
static NSString *kUILaunchImageFile  = @"UILaunchImageFile";
static NSString *kUILaunchImages  = @"UILaunchImages";
static NSString *kUILaunchStoryboardName  = @"UILaunchStoryboardName";
static NSString *kUILaunchStoryboardNameipad  = @"UILaunchStoryboardName~ipad";
static NSString *kUILaunchStoryboardNameiphone  = @"UILaunchStoryboardName~iphone";

typedef void(^SuccessBlock)(id message);
typedef void(^ErrorBlock)(NSString *errorString);
typedef void(^LogBlock)(NSString *logString);

@interface ZCAppPackageHandler : NSObject

@property (strong, readonly) NSString *bundleDisplayName;
@property (strong, readonly) NSString *bundleID;

///包的路径
@property (nonatomic, copy) NSString *packagePath;
///包解压的路径
@property (nonatomic, copy) NSString *workPath;
///xxx.app的路径
@property (nonatomic, copy) NSString *appPath;

- (instancetype)initWithPackagePath:(NSString *)path;

///解压包
- (void)unzipIpa:(void (^)(void))successBlock error:(void (^)(NSString *error))errorBlock;

- (BOOL)removeCodeSignatureDirectory;

///签名
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock  error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;

///xcode自动化出包
- (void)platformbuildresignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certiticateName:(NSString *)certificateName bundleIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName targetPath:(NSString *)targetPath log:(LogBlock)logBlock  error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;

@end

NS_ASSUME_NONNULL_END
