//
//  PlatformRowView.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/25.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ZCPlatformDataJsonModel;

@protocol PlatformRowViewDelegate <NSObject>

- (void)platformRowViewButtonClick:(ZCPlatformDataJsonModel *)selectModel;

@end

@interface PlatformRowView : NSTableRowView

@property (nonatomic, strong) ZCPlatformDataJsonModel *model;
@property (nonatomic, weak) id<PlatformRowViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
