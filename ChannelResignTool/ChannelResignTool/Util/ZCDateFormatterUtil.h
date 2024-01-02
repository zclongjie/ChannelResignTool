//
//  ZCDateFormatterUtil.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZCDateFormatterUtil : NSObject

@property (nonatomic, strong, readonly) NSDateFormatter *dateFormatter;

+ (instancetype)sharedFormatter;

//- (NSString *)timestampForDate:(NSDate *)date;
- (NSString *)yyyyMMddHHmmssSSSForDate:(NSDate *)date;
- (NSString *)yyyyMMddHHmmssForDate:(NSDate *)date;
- (NSString *)nowForDateFormat:(NSString *)dateFormat;

@end

NS_ASSUME_NONNULL_END
