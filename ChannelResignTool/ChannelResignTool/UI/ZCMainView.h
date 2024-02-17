//
//  ZCMainView.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ZCMainUIType)
{
    ZCMainUIType_Custom = 0,
    ZCMainUIType_ipaPathField = 1,
    ZCMainUIType_ipaSavePathField = 2,
    ZCMainUIType_certificateComboBox = 3,
    ZCMainUIType_provisioningComboBox = 4,
    
    ZCMainUIType_chongqian = 5,
    ZCMainUIType_appNameField = 6,
    ZCMainUIType_bundleID = 7,
    
    ZCMainUIType_appIconPath = 8,
    ZCMainUIType_launchImagePath = 9,
    
    ZCMainUIType_platformTable = 10,
    ZCMainUIType_platformTextView = 11,
    
    ZCMainUIType_LogView = 12,
};

@interface ZCMainView : NSView

@property (nonatomic, strong) NSArray *certificatesArray;
@property (nonatomic, strong) NSArray *provisioningArray;

- (void)tableReload;

@end

NS_ASSUME_NONNULL_END
