//
//  PlatformRowView.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/25.
//

#import <Cocoa/Cocoa.h>
#import "ZCPlatformModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PlatformRowViewDelegate <NSObject>

- (void)platformRowViewButtonClick:(ZCPlatformModel *)selectModel;

@end

@interface PlatformRowView : NSTableRowView

@property (nonatomic, strong) ZCPlatformModel *model;
@property (nonatomic, weak) id<PlatformRowViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
