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

/**
 比较两个版本号的大小（2.0）
 
 @param v1 第一个版本号
 @param v2 第二个版本号
 @return 版本号相等,返回0; v1小于v2,返回-1; 否则返回1.
 */
- (NSInteger)compareVersion2:(NSString *)v1 to:(NSString *)v2;

@end

NS_ASSUME_NONNULL_END
