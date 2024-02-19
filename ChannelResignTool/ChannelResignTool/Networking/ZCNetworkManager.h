//
//  ZCNetworkManager.h
//  qipajuhe
//
//  Created by 7pagame on 2018/11/6.
//  Copyright © 2018年 Vanney. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^SuccessBlock)(id responseObject);
typedef void (^FailureBlock)(NSString *error);

@interface ZCNetworkManager : NSObject

+ (void)downloadWithUrl:(NSString *)url toPath:(NSString *)toPath fileNameLast:(NSString *)fileNameLast success:(SuccessBlock)success failure:(FailureBlock)failure;

+ (void)getWithURL:(NSString *)url Params:(NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure;

+ (void)PostWithURL:(NSString *)url Params:(NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure;

@end
