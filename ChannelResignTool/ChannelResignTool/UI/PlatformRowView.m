//
//  PlatformRowView.m
//  ChannelResignTool
//
//  Created by 赵隆杰 on 2023/12/25.
//

#import "PlatformRowView.h"
#import "ZCPlatformDataJsonModel.h"
#import "Masonry.h"

@interface PlatformRowView ()

@property (nonatomic, strong) NSButton *platformButton_;

@end

@implementation PlatformRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        self.wantsLayer = YES;
        NSButton *button = [NSButton buttonWithTitle:@"" target:self action:@selector(buttonAction:)];
        [button setBezelStyle:NSBezelStyleRegularSquare];
        [button setButtonType:NSButtonTypeSwitch];
        [self addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        self.platformButton_ = button;
    }
    return self;
}

- (void)setModel:(ZCPlatformDataJsonModel *)model {
    _model = model;
    self.platformButton_.title = [NSString stringWithFormat:@"%@[%ld]", model.name, (long)model.id_];
    self.platformButton_.state = model.isSelect;
    [self.platformButton_ setEnabled:!model.isDisenable];
}

#pragma mark - Click
- (void)buttonAction:(NSButton *)button {
    _model.isSelect = !_model.isSelect;
    if (self.delegate && [self.delegate respondsToSelector:@selector(platformRowViewButtonClick:)]) {
        [self.delegate platformRowViewButtonClick:_model];
    }
}

@end
