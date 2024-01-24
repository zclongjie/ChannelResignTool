//
//  NSImage+ZCUtil.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2024/1/23.
//

#import "NSImage+ZCUtil.h"

@implementation NSImage (ZCUtil)

+ (NSImage *)mergeImages:(NSImage *)image1 withImage:(NSImage *)image2 {
    // 获取两张图片的尺寸
    NSSize size1 = image1.size;
    NSSize size2 = image2.size;

    // 计算合并后的图片尺寸（取最大宽度和最大高度）
    NSSize mergedSize = NSMakeSize(MAX(size1.width, size2.width), MAX(size1.height, size2.height));

    // 创建新的图像上下文
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:mergedSize.width
                                                                     pixelsHigh:mergedSize.height
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                                    bytesPerRow:0
                                                                   bitsPerPixel:0];

    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];

    // 在图像上下文中绘制第一张图片
    [image1 drawInRect:NSMakeRect(0, 0, size1.width, size1.height)];

    // 在图像上下文中绘制第二张图片
    [image2 drawInRect:NSMakeRect(0, 0, size2.width, size2.height)];

    // 获取合并后的图片
    NSImage *mergedImage = [[NSImage alloc] initWithSize:mergedSize];
    [mergedImage addRepresentation:bitmap];

    [NSGraphicsContext restoreGraphicsState];

    return mergedImage;
}

+ (void)saveMergedImage:(NSImage *)mergedImage toPath:(NSString *)outputPath {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:[mergedImage CGImageForProposedRect:NULL context:nil hints:nil]];
    NSData *imageData = [bitmap representationUsingType:NSPNGFileType properties:@{}];

    [imageData writeToFile:outputPath atomically:YES];
}

@end
