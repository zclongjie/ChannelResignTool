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
    ZCMainUIType_certificateComboBox = 1,
    ZCMainUIType_provisioningComboBox = 2,
    ZCMainUIType_ipaPathField = 3,
    ZCMainUIType_ipaSavePathField = 4,
    
    ZCMainUIType_appNameField = 5,
    ZCMainUIType_bundleID = 6,
    
    ZCMainUIType_appIconPath = 7,
    ZCMainUIType_launchImagePath = 8,
    
    ZCMainUIType_platformTable = 9,
    ZCMainUIType_platformTextView = 10,
};

@interface ZCMainView : NSView

@property (nonatomic, strong) NSArray *certificatesArray;
@property (nonatomic, strong) NSArray *provisioningArray;

@end

NS_ASSUME_NONNULL_END
