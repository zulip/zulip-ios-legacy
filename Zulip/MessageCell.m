#import "MessageCell.h"
#import "ZulipAppDelegate.h"
#import "UIImageView+AFNetworking.h"
#import "ZUser.h"
#import "ZulipAPIController.h"

#include <QuartzCore/QuartzCore.h>

@interface MessageCell ()

@property (nonatomic, retain) NSDateFormatter *dateFormatter;

@end

@implementation MessageCell

- (void)awakeFromNib
{
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [self.dateFormatter setDateFormat:@"HH:mm"];
}

- (void)setMessage:(RawMessage *)message
{
    self.type = message.type;

    if ([self.type isEqualToString:@"stream"]) {
        self.header.text = [NSString stringWithFormat:@"%@ > %@",
                            message.stream_recipient,
                            message.subject];
        self.recipient = message.stream_recipient;
    } else if ([self.type isEqualToString:@"private"]) {
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];

        for (ZUser *recipient in message.pm_recipients) {
            if (![recipient.email isEqualToString:[[ZulipAPIController sharedInstance] email]]) {
                [recipient_array addObject:recipient.full_name];
            }
        }
        self.recipient = [recipient_array componentsJoinedByString:@", "];
        self.header.text = [@"You and " stringByAppendingString:self.recipient];
    }

    self.sender.text = message.sender.full_name;
    self.content.text = message.content;
    // Allow multi-line content.
    self.content.lineBreakMode = NSLineBreakByWordWrapping;
    self.content.numberOfLines = 0;

    // Asynchronously load gravatar if needed
    [self.gravatar setImageWithURL:[NSURL URLWithString:message.avatar_url]];

    // Mask to get rounded corners
    // TODO apparently this can be slow during animations?
    // If it makes scrolling slow, switch over to manually
    // creating the UIImage by applying a mask with Core Graphics
    // instead of using the view's layer.
    CALayer *layer = self.gravatar.layer;
    [layer setMasksToBounds:YES];
    [layer setCornerRadius:21.0f];

    self.timestamp.text = [self.dateFormatter stringFromDate:message.timestamp];

    // When a message is on the screen, mark it as read
    message.read = YES;

}

- (void)willBeDisplayed
{
    if ([self.type isEqualToString:@"stream"]) {
        self.headerBar.backgroundColor = [[ZulipAPIController sharedInstance] streamColor:self.recipient withDefault:[MessageCell defaultStreamColor]];
    } else {
        // For non-stream messages, color cell background pale yellow (#FEFFE0).
        self.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255
                                                   blue:224.0/255 alpha:1];
        self.headerBar.backgroundColor = [UIColor colorWithRed:51.0/255
                                                            green:51.0/255
                                                             blue:51.0/255
                                                            alpha:1];
        self.header.textColor = [UIColor whiteColor];
    }
}

+ (CGFloat)heightForCellWithMessage:(RawMessage *)message
{
    NSString *cellText = [message valueForKey:@"content"];
    UIFont *cellFont = [UIFont systemFontOfSize:12];
    CGSize constraintSize = CGSizeMake(262.0, CGFLOAT_MAX); // content width from xib = 267.
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:NSLineBreakByWordWrapping];

    // Full cell height of 77 - default content height of 36 = 41. + a little bit of bottom padding.
    return fmaxf(77.0f, labelSize.height + 45.0f);
}

#pragma mark - UITableViewCell

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    self.content.lineBreakMode = NSLineBreakByWordWrapping;
    self.content.numberOfLines = 0;
    [self.content sizeToFit];
}

- (NSURL *)gravatarUrl:(NSString *)gravatarHash
{
    return [NSURL URLWithString:
            [NSString stringWithFormat:
             @"https://secure.gravatar.com/avatar/%@?d=identicon&s=30",
             gravatarHash]];
}


+ (UIColor *)defaultStreamColor {
    return [UIColor colorWithRed:187.0f/255
                           green:187.0f/255
                            blue:187.0f/255
                           alpha:1];
}

+ (NSString *)reuseIdentifier {
    return @"CustomCellIdentifier";
}

@end
