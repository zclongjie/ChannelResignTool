//
//  ZCProvisioningProfile.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZCProvisioningProfile : NSObject

- (instancetype)initWithPath:(NSString *)path;

@property (nonatomic, strong, readonly) NSString    *name;
@property (nonatomic, strong, readonly) NSString    *teamName;
@property (nonatomic, strong, readonly) NSString    *valid;
@property (nonatomic, assign, readonly) NSString    *debug;
@property (nonatomic, strong, readonly) NSDate      *creationDate;
@property (nonatomic, strong, readonly) NSDate      *expirationDate;
@property (nonatomic, strong, readonly) NSString    *UUID;
@property (nonatomic, strong, readonly) NSArray     *devices;
@property (nonatomic, assign, readonly) NSInteger   timeToLive;
@property (nonatomic, strong, readonly) NSString    *applicationIdentifier;
@property (nonatomic, strong, readonly) NSString    *bundleIdentifier;
@property (nonatomic, strong, readonly) NSArray     *certificates;
@property (nonatomic, assign, readonly) NSInteger   version;
@property (nonatomic, assign, readonly) NSArray     *prefixes;
@property (nonatomic, strong, readonly) NSString    *appIdName;
@property (nonatomic, strong, readonly) NSString    *teamIdentifier;
@property (nonatomic, strong, readonly) NSString    *path;

@end

NS_ASSUME_NONNULL_END
