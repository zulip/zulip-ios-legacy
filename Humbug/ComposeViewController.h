#import <UIKit/UIKit.h>
#import "HumbugAppDelegate.h"

@interface ComposeViewController : UIViewController <UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UITextField *subject;
@property (strong, nonatomic) IBOutlet UITextField *stream;
@property (strong, nonatomic) IBOutlet UITextView *content;

@property(nonatomic,retain) HumbugAppDelegate *delegate;

- (IBAction) send;

@end
