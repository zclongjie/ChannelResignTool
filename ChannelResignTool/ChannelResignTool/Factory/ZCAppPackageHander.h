//
//  ZCAppPackageHander.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *kQPJHPLISTFileName = @"QPJHPLIST.plist";
static NSString *kPayloadDirName = @"Payload";
static NSString *kInfoPlistFileName = @"Info.plist";
static NSString *kCFBundleDisplayName = @"CFBundleDisplayName";
static NSString *kCFBundleName = @"CFBundleName";
static NSString *kCFBundleIdentifier = @"CFBundleIdentifier";
static NSString *kCodeSignatureDirectory = @"_CodeSignature";
static NSString *kEntitlementsPlistFileName = @"Entitlements.plist";
static NSString *kEmbeddedProvisioningFileName  = @"embedded";
static NSString *kUILaunchImageFile  = @"UILaunchImageFile";
static NSString *kUILaunchImages  = @"UILaunchImages";
static NSString *kUILaunchStoryboardName  = @"UILaunchStoryboardName";
static NSString *kUILaunchStoryboardNameipad  = @"UILaunchStoryboardName~ipad";
static NSString *kUILaunchStoryboardNameiphone  = @"UILaunchStoryboardName~iphone";

typedef NS_ENUM(NSInteger, BlockType)
{
    BlockType_Unzip = 0,
    BlockType_Entitlements,
    BlockType_InfoPlist,
    BlockType_EmbeddedProvision,
    BlockType_DoCodesign,
    BlockType_ZipPackage,
    BlockType_PlatformUnzipFiles,
    BlockType_PlatformEditFiles,
    BlockType_PlatformShow,
    BlockType_PlatformAppIcon,
    BlockType_PlatformSDKDownload,
    BlockType_PlatformAllEnd
};

typedef void(^SuccessBlock)(BlockType type, id message);
typedef void(^ErrorBlock)(BlockType type, NSString *errorString);
typedef void(^LogBlock)(BlockType type, NSString *logString);

@class ZCProvisioningProfile;

@interface ZCAppPackageHander : NSObject

@property (nonatomic, strong) NSFileManager *manager;//全局文件管理

@property (nonatomic, assign) NSInteger gameId;

@property (nonatomic, copy) NSString *bundleDisplayName;
@property (nonatomic, copy) NSString *bundleName;
@property (nonatomic, copy) NSString *bundleIdentifier;

///包解压的路径
@property (nonatomic, copy) NSString *temp_workPath;//先放临时路径，为下个渠道直接使用

@property (nonatomic, copy) NSString *workPath;//从临时路径copy
///xxx.app的路径
@property (nonatomic, copy) NSString *appPath;

///解压包
- (void)unzipIpaLog:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;

- (instancetype)initWithPackagePath:(NSString *)path;

- (BOOL)removeCodeSignatureDirectory;

- (void)temp_workPathToWorkPath;

- (void)createEntitlementsWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;
- (void)editEmbeddedProvision:(ZCProvisioningProfile *)provisoiningProfile  log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;
- (void)doCodesignCertificateName:(NSString *)certificateName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;

///母包签名
- (void)resignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certificateName:(NSString *)certificateName useMobileprovisionBundleID:(BOOL)useMobileprovisionBundleID bundleIdField_str:(NSString *)bundleIdField_str appNameField_str:(NSString *)appNameField_str targetPath:(NSString *)targetPath log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;
///渠道出包
- (void)platformbuildresignWithProvisioningProfile:(ZCProvisioningProfile *)provisioningProfile certificateName:(NSString *)certificateName platformModels:(NSArray *)platformModels appIconPath:(NSString *)appIconPath launchImagePath:(NSString *)launchImagePath targetPath:(NSString *)targetPath log:(LogBlock)logBlock  error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock;
@end

NS_ASSUME_NONNULL_END
