//
//  NSImage+ZCUtil.h
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (ZCUtil)

///合并2张图片
+ (NSImage *)mergeImages:(NSImage *)image1 withImage:(NSImage *)image2;

///保存NSImage
+ (void)saveMergedImage:(NSImage *)mergedImage toPath:(NSString *)outputPath;

@end

NS_ASSUME_NONNULL_END
