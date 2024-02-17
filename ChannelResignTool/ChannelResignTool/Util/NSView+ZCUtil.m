//
//  NSView+ZCUtil.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/2/3.
//

#import "NSView+ZCUtil.h"
#import <objc/runtime.h>

@interface NSView ()

@end

@implementation NSView (ZCUtil)

- (void)setBackgroundColor:(NSColor *)backgroundColor {
    CALayer *viewLayer = [CALayer layer];
    [self setWantsLayer:YES];
    [self setLayer:viewLayer];
    self.layer.backgroundColor = backgroundColor.CGColor;
    [self setNeedsDisplay:YES];
}
- (NSColor *)backgroundColor {
    return [NSColor colorWithCGColor:self.layer.backgroundColor];
}

//static const char *kCustomTagKey = "CustomTagKey";
//
//@dynamic customTag;
//
//- (NSInteger)customTag {
//    return [objc_getAssociatedObject(self, kCustomTagKey) integerValue];
//}
//
//- (void)setCustomTag:(NSInteger)customTag {
//    objc_setAssociatedObject(self, kCustomTagKey, @(customTag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}

@end
