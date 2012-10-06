#import "MessageCell.h"

@implementation MessageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    self.content.lineBreakMode = UILineBreakModeWordWrap;
    self.content.numberOfLines = 0;
    [self.content sizeToFit];
}

+ (NSString *)reuseIdentifier {
    return @"CustomCellIdentifier";
}

@end
