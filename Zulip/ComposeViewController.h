#import <UIKit/UIKit.h>
#import "ZulipAppDelegate.h"

@interface ComposeViewController : UIViewController <UITextViewDelegate, UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UITextField *subject;
@property (strong, nonatomic) IBOutlet UITextField *recipient;
@property (strong, nonatomic) IBOutlet UITextField *privateRecipient;
@property (strong, nonatomic) IBOutlet UITextView *content;

@property(nonatomic,retain) ZulipAppDelegate *delegate;
@property(nonatomic,retain) NSString *type;
@property (nonatomic, retain) NSMutableArray *entryFields;

- (IBAction) send;

@end
