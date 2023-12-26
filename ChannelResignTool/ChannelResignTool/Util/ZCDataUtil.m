//
//  ZCDataUtil.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/26.
//

#import "ZCDataUtil.h"

@implementation ZCDataUtil

+ (instancetype)shareInstance {
    static ZCDataUtil *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ZCDataUtil alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (id)readJsonFile:(NSString *)jsonPath {
    if (jsonPath) {
        // 将文件数据化
        NSData *data = [[NSData alloc] initWithContentsOfFile:jsonPath];
        if (data) {
            // 对数据进行JSON格式化并返回字典形式
            NSError *err;

                    NSDictionary *configFirstDic = [NSJSONSerialization JSONObjectWithData:data

                                                                        options:NSJSONReadingMutableContainers

                                                                          error:&err];
            
            return configFirstDic;
        }
    }
    return nil;
}


@end
