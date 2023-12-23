//
//  ZCManuaQueue.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import "ZCManuaQueue.h"

@implementation ZCManuaQueue {
    NSMutableArray *operations;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        operations = @[].mutableCopy;
    }
    return self;
}

- (void)addOperation:(NSOperation *)operation {
    [operations addObject:operation];
}

- (void)next {
    if (operations.count) {
        NSOperation *operation = [operations objectAtIndex:0];
        operation.completionBlock = ^{
            [self->operations removeObjectAtIndex:0];
        };
        [operation start];
    } else {
        if (self.noOperationBlock) {
            self.noOperationBlock();
        }
    }
}

- (void)cancelAll {
    [operations removeAllObjects];
}

@end
