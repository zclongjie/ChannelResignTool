//
//  ZCDataUtil.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZCDataUtil : NSObject

+ (instancetype)shareInstance;
- (id)readJsonFile:(NSString *)jsonPath;

@end

NS_ASSUME_NONNULL_END
