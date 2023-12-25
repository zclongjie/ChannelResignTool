//
//  PlatformRowView.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/25.
//

#import "PlatformRowView.h"

@implementation PlatformRowViewModel

@end

@interface PlatformRowView ()

@property (weak) IBOutlet NSButton *platformButton;


@end

@implementation PlatformRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)setModel:(PlatformRowViewModel *)model {
    _model = model;
    self.platformButton.title = model.name;
}
- (IBAction)platformButtonClick:(NSButton *)sender {
    if (self.delegate && [self.delegate respondsToSelector:@selector(platformRowViewButtonClick:)]) {
        [self.delegate platformRowViewButtonClick:_model.platformId];
    }
}

@end
