//
//  SidebarStreamCell.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "SidebarStreamCell.h"
#import "ZulipAPIController.h"
#import "UIColor+HexColor.h"

@interface SidebarStreamCell ()

@end

@implementation SidebarStreamCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.stream = nil;
    }
    return self;
}

- (void)setShortcut:(SIDEBAR_SHORTCUTS)shortcut
{
    _shortcut = shortcut;
    NarrowOperators *op = [[NarrowOperators alloc] init];

    switch (shortcut) {
        case HOME:
        {
            self.name.text = @"Home";
            // Magic to go  back to the main view
            [op setInHomeView];
            UIImage *image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"home" ofType:@"png"]];
            self.gravatar.image = image;
            break;

        }
        case PRIVATE_MESSAGES:
        {
            self.name.text = @"Private Messages";
            [op setPrivateMessages];

            UIImage *image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"user" ofType:@"png"]];
            self.gravatar.image = image;
            break;
        }
        default:
            break;
    }
    _narrow = op;
}

- (void)setStream:(ZSubscription *)subscription
{
    _shortcut = STREAM;
    _stream = subscription;
    self.name.text = subscription.name;

    NarrowOperators *op = [[NarrowOperators alloc] init];
    [op addStreamNarrow:subscription.name];
    _narrow = op;

    // TODO contentScaleFactor is always 1.0?!
    int size = (self.gravatar.bounds.size.height - 6) * self.contentScaleFactor; // padding
    self.gravatar.image = [self streamColorSwatchWithSize:size andColor:subscription.color];
}

#pragma mark - Drawing Methods

- (UIImage *)streamColorSwatchWithSize:(int)height andColor:(NSString *)colorRGB
{
    UIGraphicsBeginImageContext(CGSizeMake(height, height));
    CGContextRef context = UIGraphicsGetCurrentContext();
	UIGraphicsPushContext(context);

    CGRect bounds = CGRectMake(0, 0, height, height);
    CGContextAddEllipseInRect(context, bounds);
    CGContextClip(context);

    UIColor *color = [UIColor colorWithHexString:colorRGB defaultColor:[UIColor grayColor]];
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, bounds);

    UIGraphicsPopContext();
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

    return result;
}

@end
