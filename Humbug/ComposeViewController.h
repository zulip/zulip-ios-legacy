#import <UIKit/UIKit.h>
#import "HumbugAppDelegate.h"

@interface ComposeViewController : UIViewController <UITextViewDelegate, UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UITextField *subject;
@property (strong, nonatomic) IBOutlet UITextField *recipient;
@property (strong, nonatomic) IBOutlet UITextField *privateRecipient;
@property (strong, nonatomic) IBOutlet UITextView *content;

@property(nonatomic,retain) HumbugAppDelegate *delegate;
@property(nonatomic,retain) NSString *type;
@property (nonatomic, retain) NSMutableArray *entryFields;

- (IBAction) send;

@end
