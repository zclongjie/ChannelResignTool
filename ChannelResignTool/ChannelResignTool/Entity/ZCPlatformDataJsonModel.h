//
//  ZCPlatformDataJsonModel.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/2.
//

#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZCPlatformDataJsonModel : BaseModel

@property (nonatomic, assign) NSInteger id_;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *alias;
@property (nonatomic, strong) NSDictionary *down_info;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) BOOL isDisenable;

@end

NS_ASSUME_NONNULL_END
