//
//  ZCRunLoop.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZCRunLoop : NSObject

@property (nonatomic, assign) BOOL isSuspend;

- (void)run:(void (^)(void))block;
- (void)stop:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
