//
//  ZCPlatformModel.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/2.
//

#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZCPlatformModel : BaseModel

@property (nonatomic, assign) NSInteger id_;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *alias;
@property (nonatomic, strong) NSDictionary *parameter;

//@property (nonatomic, strong) NSDictionary *down_info;

//@property (nonatomic, strong) NSString *version;


@property (nonatomic, strong) NSString *gameName;
@property (nonatomic, strong) NSString *bundleIdentifier;
@property (nonatomic, strong) NSString *isLan;
@property (nonatomic, assign) BOOL isSelect;

@end

NS_ASSUME_NONNULL_END
