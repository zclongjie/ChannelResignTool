//
//  ZCDateFormatterUtil.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/23.
//

#import "ZCDateFormatterUtil.h"

@implementation ZCDateFormatterUtil

static ZCDateFormatterUtil *instance;
+ (instancetype)sharedFormatter {
    @synchronized (self) {
        if (instance == nil) {
            instance = [[ZCDateFormatterUtil alloc] init];
            return instance;
        }
    }
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setLocale:[NSLocale currentLocale]];
    }
    return self;
}

- (void)dealloc {
    _dateFormatter = nil;
}

//- (NSString *)timestampForDate:(NSDate *)date {
//    if(!date) {
//        return nil;
//    }
//    [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
//    [self.dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
//    return [self.dateFormatter stringFromDate:date];
//}

- (NSString *)yyyyMMddHHmmssSSSForDate:(NSDate *)date {
    if (!date) {
        return nil;
    }
    self.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss SSS";
    return [self.dateFormatter stringFromDate:date];
}
- (NSString *)yyyyMMddHHmmssForDate:(NSDate *)date {
    if (!date) {
        return nil;
    }
    self.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [self.dateFormatter stringFromDate:date];
}

- (NSString *)nowForDateFormat:(NSString *)dateFormat {
    self.dateFormatter.dateFormat = dateFormat;
    return [self.dateFormatter stringFromDate:[NSDate date]];
}

@end
