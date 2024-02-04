//
//  ZCNetworkingViewModel.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SuccessBlock)(id responseObject);
typedef void (^FailureBlock)(NSString *error);

@interface ZCNetworkingViewModel : NSObject
//data.json
+ (void)downloadWithDataConfigUrlSuccess:(SuccessBlock)success failure:(FailureBlock)failure;
//208.json
+ (void)downloadWithChannelConfigUrl:(NSInteger)channelId success:(SuccessBlock)success failure:(FailureBlock)failure;
//zaoyouxi.zip
+ (void)downloadWithChannelSDKUrl:(NSString *)alias channelVersion:(NSString *)channelVersion success:(SuccessBlock)success failure:(FailureBlock)failure;

+ (void)getGameConfigByGameId:(NSInteger)gameId ByChannelId:(NSInteger)channelId success:(SuccessBlock)success failure:(FailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
