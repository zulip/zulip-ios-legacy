//
//  UserCell.h
//  Zulip
//
//  Created by Humbug on 10/21/13.
//
//

#import <UIKit/UIKit.h>

@interface UserCell : UITableViewCell


// the name if it's available, otherwise the email address
@property (strong, nonatomic) IBOutlet UILabel *title;
// the email address if the name is available, otherwise nothing
@property (strong, nonatomic) IBOutlet UILabel *subtitle;
@property (strong, nonatomic) IBOutlet UIImageView *gravatar;


@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *email;
@property (strong, nonatomic) NSString *gravatarUrl;

+ (NSString *)reuseIdentifier;
- (void)setUserWithEmail:(NSString *)email;

@end
