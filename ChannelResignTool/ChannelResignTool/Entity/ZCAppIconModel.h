//
//  ZCAppIconModel.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/8.
//

#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZCAppIconImageItem : NSObject

@property (nonatomic, copy) NSString *size;
@property (nonatomic, copy) NSString *idiom;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *scale;

@end

@interface ZCAppIconInfo : NSObject

@property (nonatomic, assign) int version;
@property (nonatomic, copy) NSString *author;

@end

@interface ZCAppIconModel : NSObject

@property (nonatomic, strong) NSArray <ZCAppIconImageItem *>*images;
@property (nonatomic, strong) ZCAppIconInfo *info;

@end

NS_ASSUME_NONNULL_END
