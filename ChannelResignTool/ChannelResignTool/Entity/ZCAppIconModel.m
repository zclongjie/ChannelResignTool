//
//  ZCAppIconModel.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/8.
//

#import "ZCAppIconModel.h"

@implementation ZCAppIconImageItem

@end

@implementation ZCAppIconInfo

@end

@implementation ZCAppIconModel

+ (NSDictionary *)mj_objectClassInArray
{
        return @{
                 @"images":@"ZCAppIconImageItem"
                 };
}

@end
