#import "MessageCell.h"
#import "ZulipAppDelegate.h"
#import "UIImageView+AFNetworking.h"
#import "ZUser.h"
#import "ZulipAPIController.h"

@implementation MessageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setMessage:(ZMessage *)message
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
    self.content.lineBreakMode = UILineBreakModeWordWrap;
    self.content.numberOfLines = 0;

    // Asynchronously load gravatar if needed
    [self.gravatar setImageWithURL:[NSURL URLWithString:message.avatar_url]];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"HH:mm"];
    self.timestamp.text = [dateFormatter stringFromDate:message.timestamp];

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

+ (CGFloat)heightForCellWithMessage:(ZMessage *)message
{
    NSString *cellText = [message valueForKey:@"content"];
    UIFont *cellFont = [UIFont systemFontOfSize:12];
    CGSize constraintSize = CGSizeMake(262.0, CGFLOAT_MAX); // content width from xib = 267.
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];

    // Full cell height of 77 - default content height of 36 = 41. + a little bit of bottom padding.
    return fmax(77.0, labelSize.height + 45);
}

#pragma mark - UITableViewCell

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    self.content.lineBreakMode = UILineBreakModeWordWrap;
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
    return [UIColor colorWithRed:187.0/255
                           green:187.0/255
                            blue:187.0/255
                           alpha:1];
}

+ (NSString *)reuseIdentifier {
    return @"CustomCellIdentifier";
}

@end
