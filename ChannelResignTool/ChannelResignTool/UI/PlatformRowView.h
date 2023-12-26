//
//  PlatformRowView.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/25.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlatformRowViewModel : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSString *platformId;
@property (nonatomic, assign) BOOL isSelect;

@end

@protocol PlatformRowViewDelegate <NSObject>

- (void)platformRowViewButtonClick:(PlatformRowViewModel *)selectModel;

@end

@interface PlatformRowView : NSTableRowView

@property (nonatomic, strong) PlatformRowViewModel *model;
@property (nonatomic, weak) id<PlatformRowViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
