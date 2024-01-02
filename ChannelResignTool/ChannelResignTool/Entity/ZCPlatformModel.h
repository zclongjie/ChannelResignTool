//
//  ZCPlatformModel.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZCPlatformModel : NSObject

@property (nonatomic, strong) NSString *platformName;
@property (nonatomic, strong) NSString *alias;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *platformId;

@property (nonatomic, strong) NSString *gameName;
@property (nonatomic, strong) NSString *bundleIdentifier;
@property (nonatomic, strong) NSString *isLan;
@property (nonatomic, strong) NSDictionary *parameter;
@property (nonatomic, assign) BOOL isSelect;

@end

NS_ASSUME_NONNULL_END
