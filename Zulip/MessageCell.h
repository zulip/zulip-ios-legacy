#import <UIKit/UIKit.h>

#import "DTAttributedTextContentView.h"
#import "DTCoreText.h"

#import "RawMessage.h"

@protocol MessageCellDelegate <NSObject>

@optional
- (void)openLink:(NSURL *)URL;

@end


@interface MessageCell : UITableViewCell <DTAttributedTextContentViewDelegate>

- (void)willBeDisplayedWithPreviousMessage:(RawMessage *)previousMessage;

+ (NSString *)reuseIdentifier;
+ (CGFloat)heightForCellWithMessage:(RawMessage *)message
                    previousMessage:(RawMessage *)previousMessage;

@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UILabel *headerBar;
@property (strong, nonatomic) IBOutlet UILabel *sender;
@property (strong, nonatomic) IBOutlet UILabel *timestamp;
@property (strong, nonatomic) IBOutlet UIImageView *gravatar;
@property (strong, nonatomic) IBOutlet DTAttributedTextContentView *attributedTextView;

@property (strong, nonatomic) NSString *type;
@property (strong, nonatomic) NSString *recipient;

@property (strong, nonatomic) RawMessage *message;

@property (nonatomic, weak) IBOutlet id <MessageCellDelegate> delegate;

@end
