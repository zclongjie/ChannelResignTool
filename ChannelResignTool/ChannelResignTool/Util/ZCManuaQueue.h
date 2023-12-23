//
//  ZCManuaQueue.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZCManuaQueue : NSObject

- (void)addOperation:(NSOperation *)operation;

- (void)next;
- (void)cancelAll;

@property (nonatomic, copy) void(^noOperationBlock)(void);

@end

NS_ASSUME_NONNULL_END
