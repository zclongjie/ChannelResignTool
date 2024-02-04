//
//  ZCHttpConfig.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#ifndef ZCHttpConfig_h
#define ZCHttpConfig_h

#define CHANNELRESIGNTOOL_PATH [[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleExecutableKey]]


#define SuccessCode @"200"

#define base7paUrl @"https://doc.7pa.com/SDK"
#define configBaseUrl @"https://game-server.7pa.com/plat"
//data.json
#define dataConfigUrl [NSString stringWithFormat:@"%@/Resources/IOS_SDK/channel/data.json",base7paUrl]

//#define sdkPackageToolBase @"$base7paUrl/Resources/SDKPackageTool"
//#define sdkPackageToolConfig @"$sdkPackageToolBase/config.json"
//#define getGameConfigByChannel(gameId :Int,channelId:Int) = "$configBaseUrl/index?game_id=$gameId&plat_id=$channelId&os_type=1"
//获取游戏的所有渠道
//#define getGameAllChannel(gameId :Int) = "$configBaseUrl/list?os_type=1&game_id=$gameId"

//208.json
#define getChannelConfigUrl(channelId) [NSString stringWithFormat:@"%@/Resources/IOS_SDK/channel/list/%ld.json",base7paUrl,(long)channelId]

//zaoyouxi.zip
#define getChannelSDKUrl(alias) [NSString stringWithFormat:@"%@/Resources/IOS_SDK/channel/dysdk/%@.zip",base7paUrl,alias]

#endif /* ZCHttpConfig_h */
