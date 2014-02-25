//
//  StreamProgressView.m
//  Zulip
//
//  Created by Michael Walker on 2/25/14.
//
//

#import "StreamProgressView.h"

@implementation StreamProgressView

+ (CGFloat)height {
    return 80.0;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [self addSubview:spinner];
        spinner.center = self.center;
        spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        spinner.color = [UIColor grayColor];
        [spinner startAnimating];
    }
    return self;
}

@end
