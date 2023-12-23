//
//  ZCRunLoop.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import "ZCRunLoop.h"

@implementation ZCRunLoop

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isSuspend = NO;
    }
    return self;
}

- (void)run:(void (^)(void))block {
    self.isSuspend = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_TIME_NOW, 0), ^{
        while (!self.isSuspend) {
            block();
            [[NSRunLoop currentRunLoop] runMode:NSRunLoopCommonModes beforeDate:[NSDate distantFuture]];
        }
    });
}

- (void)stop:(void (^)(void))block {
    self.isSuspend = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

@end
