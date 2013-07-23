#import <UIKit/UIKit.h>

@interface MessageCell : UITableViewCell

- (void)setMessage:(NSDictionary *)dict;

+ (NSString *)reuseIdentifier;

@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UILabel *headerBar;
@property (strong, nonatomic) IBOutlet UILabel *sender;
@property (strong, nonatomic) IBOutlet UILabel *timestamp;
@property (strong, nonatomic) IBOutlet UILabel *content;
@property (strong, nonatomic) IBOutlet UIImageView *gravatar;

@property (strong, nonatomic) NSString *type;
@property (strong, nonatomic) NSString *recipient;

@end
