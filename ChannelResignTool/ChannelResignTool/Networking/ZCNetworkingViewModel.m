//
//  ZCNetworkingViewModel.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#import "ZCNetworkingViewModel.h"
#import "ZCHttpConfig.h"
#import "ZCFileHelper.h"
#import "ZCNetworkManager.h"


NSString *const myResponseErrorKey = @"com.alamofire.serialization.response.error.response";
typedef void (^SuccessBlock)(id responseObject);
typedef void (^FailureBlock)(NSString *error);

@interface ZCNetworkingViewModel ()

@end

@implementation ZCNetworkingViewModel

+ (void)downloadWithDataConfigUrlSuccess:(SuccessBlock)success failure:(FailureBlock)failure {
    [ZCNetworkManager downloadWithUrl:dataConfigUrl toPath:[ZCFileHelper sharedInstance].PlatformSDKJson fileNameLast:nil success:^(id responseObject) {
        success(responseObject);
    } failure:^(NSString *error) {
        failure(error);
    }];
}

//208.json
+ (void)downloadWithChannelConfigUrl:(NSInteger)channelId success:(SuccessBlock)success failure:(FailureBlock)failure {
    [ZCNetworkManager downloadWithUrl:getChannelConfigUrl(channelId) toPath:[ZCFileHelper sharedInstance].PlatformSDKJson fileNameLast:nil success:^(id responseObject) {
        success(responseObject);
    } failure:^(NSString *error) {
        failure(error);
    }];
}
//zaoyouxi.zip
+ (void)downloadWithChannelSDKUrl:(NSString *)alias channelVersion:(NSString *)channelVersion success:(SuccessBlock)success failure:(FailureBlock)failure {
    NSString *fileNameLast = [NSString stringWithFormat:@"_%@", [channelVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
    [ZCNetworkManager downloadWithUrl:getChannelSDKUrl(alias) toPath:[ZCFileHelper sharedInstance].PlatformSDKDownloadZip fileNameLast:fileNameLast success:^(id responseObject) {
        success(responseObject);
    } failure:^(NSString *error) {
        failure(error);
    }];
}

+ (void)getGameConfigByGameId:(NSInteger)gameId ByChannelId:(NSInteger)channelId success:(nonnull SuccessBlock)success failure:(nonnull FailureBlock)failure {
    NSString *URLString = [NSString stringWithFormat:@"%@/index",configBaseUrl];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"game_id"] = @(gameId);
    params[@"plat_id"] = @(channelId);
    params[@"os_type"] = @2;

    [ZCNetworkManager getWithURL:URLString Params:params success:^(id responseObject) {
        NSLog(@"%@", responseObject);
        NSString *code = [NSString stringWithFormat:@"%@", responseObject[@"code"]];
        if ([code isEqualToString:SuccessCode]) {
            success(responseObject[@"data"]);
        }
            
    } failure:^(NSString *error) {
        failure(error);
    }];
}

@end
