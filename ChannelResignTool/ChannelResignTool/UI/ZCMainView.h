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
    ZCMainUIType_ipaPathField = 0,
    ZCMainUIType_ipaSavePathField = 1,
    ZCMainUIType_certificateComboBox = 2,
    ZCMainUIType_provisioningComboBox = 3,
    
    ZCMainUIType_appNameField = 4,
    ZCMainUIType_changeBundleID = 5,
    ZCMainUIType_proBundleID = 6,
    ZCMainUIType_chongqian = 7,
    
    ZCMainUIType_appIconPath = 8,
    ZCMainUIType_launchImagePath = 9,
    
    ZCMainUIType_platformTable = 10,
    ZCMainUIType_platformTextView = 11,
    ZCMainUIType_platformResign = 12,
    
    ZCMainUIType_LogView = 13,
};

@protocol ZCMainViewDelegate <NSObject>

- (void)viewButtonClick:(ZCMainUIType)uiType;

@end

@interface ZCMainView : NSView

@property (nonatomic, strong) NSTextField *ipaPathField_;
@property (nonatomic, strong) NSButton *browseIpaPathButton_;
@property (nonatomic, strong) NSTextField *ipaSavePathField_;
@property (nonatomic, strong) NSButton *browseIpaSavePathButton_;
@property (nonatomic, strong) NSComboBox *certificateComboBox_;
@property (nonatomic, strong) NSComboBox *provisioningComboBox_;

@property (nonatomic, strong) NSTextField *appNameField_;
@property (nonatomic, strong) NSButton *radioButton_;
@property (nonatomic, strong) NSTextField *bundleIdField_;
@property (nonatomic, strong) NSButton *bundleIDButton_;
@property (nonatomic, strong) NSButton *ipaResignButton_;

@property (nonatomic, strong) NSTextField *appIconPathField_;
@property (nonatomic, strong) NSButton *browseAppIconPathButton_;
@property (nonatomic, strong) NSTextField *launchImagePathField_;
@property (nonatomic, strong) NSButton *browseLaunchImagePathButton_;

@property (nonatomic, strong) NSTableView *platformTableView_;
@property (nonatomic, strong) NSTextView *showSelectedPlatformField_;
@property (nonatomic, strong) NSButton *platformSignButton_;

@property (nonatomic, strong) NSTextView *logField_;

@property (nonatomic, strong) NSButton *cleanLogButton_;
@property (nonatomic, strong) NSButton *cleanPlatformButton_;
//@property (nonatomic, strong) NSButton *cleanAllButton;

@property (nonatomic, strong) NSArray *certificatesArray;
@property (nonatomic, strong) NSArray *provisioningArray;

@property (nonatomic, weak) id<ZCMainViewDelegate> delegate;

- (void)showSelectPlatformView:(NSMutableArray *)selectPlatformNameArray;
- (void)showResigningPlatform:(NSString *)logString;
- (void)addLog:(NSString *)log withColor:(NSColor *)color;
- (void)enableControls;
- (void)disenableControls;

@end

NS_ASSUME_NONNULL_END
