//
//  ZCChannelDataJsonModel.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZCChannelDataJsonModel : BaseModel

@property (nonatomic, strong) NSString *id_;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *alias;
@property (nonatomic, strong) NSString *down_info;

@end

NS_ASSUME_NONNULL_END
