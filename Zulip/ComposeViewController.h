#import <UIKit/UIKit.h>
#import "ZulipAppDelegate.h"

@interface ComposeViewController : UIViewController <UITextFieldDelegate, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITextField *subject;
@property (strong, nonatomic) IBOutlet UITextField *recipient;
@property (strong, nonatomic) IBOutlet UITextField *privateRecipient;
@property (strong, nonatomic) IBOutlet UITextView *content;
@property (strong, nonatomic) IBOutlet UITableView *completionsTableView;

@property(nonatomic,retain) ZulipAppDelegate *delegate;
@property(nonatomic,retain) NSString *type;
@property (nonatomic, retain) NSMutableArray *entryFields;
@property (nonatomic, copy) NSDictionary *fullNameLookupDict;
@property (nonatomic, retain) NSMutableArray *completionMatches;

- (id)initWithReplyTo:(RawMessage *)message;

- (IBAction) send;

@end
