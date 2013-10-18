//
//  UserCell.m
//  Zulip
//
//  Created by Humbug on 10/21/13.
//
//

#import "UserCell.h"
#import "UIImageView+AFNetworking.h"
#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"
#import "ZUser.h"

@implementation UserCell

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

    // Configure the view for the selected state
}

- (void)setUserWithEmail:(NSString *)email
{

    ZUser *user = [[ZulipAPIController sharedInstance] getPersonFromCoreDataWithEmail:email];
    if (user)
    {
        self.gravatarUrl = user.avatar_url;
        [self.gravatar setImageWithURL:[NSURL URLWithString:self.gravatarUrl]];
        self.title.text = self.name = user.full_name;
        self.subtitle.text = self.email = user.email;
    }
    else
    {
        self.gravatarUrl = nil;
        self.gravatar.image = nil;
        self.title.text = self.email = email;
        self.subtitle.text = self.name = nil;
    }
}


+ (NSString *)reuseIdentifier {
    return @"UserCellIdentifier";
}


@end
