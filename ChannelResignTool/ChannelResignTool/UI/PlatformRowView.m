//
//  PlatformRowView.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/25.
//

#import "PlatformRowView.h"

@interface PlatformRowView ()

@property (weak) IBOutlet NSButton *platformButton;


@end

@implementation PlatformRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)setModel:(ZCPlatformModel *)model {
    _model = model;
    self.platformButton.title = [NSString stringWithFormat:@"%@[%@]", model.platformName, model.platformId];
    self.platformButton.state = model.isSelect;
}
- (IBAction)platformButtonClick:(NSButton *)sender {
    _model.isSelect = !_model.isSelect;
    if (self.delegate && [self.delegate respondsToSelector:@selector(platformRowViewButtonClick:)]) {
        [self.delegate platformRowViewButtonClick:_model];
    }
}

@end
