#import "MessageCell.h"
#import "HumbugAppDelegate.h"
#import "UIImageView+AFNetworking.h"

@implementation MessageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setMessage:(NSDictionary *)dict
{
    self.type = [dict objectForKey:@"type"];
    self.recipient = [dict objectForKey:@"display_recipient"];

    if ([self.type isEqualToString:@"stream"]) {
        self.header.text = [NSString stringWithFormat:@"%@ > %@",
                            [dict objectForKey:@"display_recipient"],
                            [dict objectForKey:@"subject"]];
    } else if ([self.type isEqualToString:@"private"]) {
        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];

        HumbugAppDelegate *appDelegate = (HumbugAppDelegate *)[[UIApplication sharedApplication] delegate];
        for (NSDictionary *recipient in recipients) {
            if (![[recipient valueForKey:@"email"] isEqualToString:[appDelegate email]]) {
                [recipient_array addObject:[recipient objectForKey:@"full_name"]];
            }
        }
        self.header.text = [@"You and " stringByAppendingString:[recipient_array componentsJoinedByString:@", "]];
    }

    self.sender.text = [dict objectForKey:@"sender_full_name"];
    self.content.text = [dict objectForKey:@"content"];
    // Allow multi-line content.
    self.content.lineBreakMode = UILineBreakModeWordWrap;
    self.content.numberOfLines = 0;

    // Asynchronously load gravatar if needed
    NSString *ghash = [dict objectForKey:@"gravatar_hash"];
    [self.gravatar setImageWithURL:[self gravatarUrl:ghash]];

    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]
                              autorelease]];
    [dateFormatter setDateFormat:@"HH:mm"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:
                    [[dict objectForKey:@"timestamp"] doubleValue]];
    self.timestamp.text = [dateFormatter stringFromDate:date];

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

+ (NSString *)reuseIdentifier {
    return @"CustomCellIdentifier";
}

@end
