#import <UIKit/UIKit.h>
#import "ZulipAppDelegate.h"

@class ZUser;

@interface ComposeViewController : UIViewController <UITextFieldDelegate, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITextField *subject;
@property (strong, nonatomic) IBOutlet UITextField *recipient;
@property (strong, nonatomic) IBOutlet UITextField *privateRecipient;
@property (strong, nonatomic) IBOutlet UITextView *content;
@property (strong, nonatomic) IBOutlet UITableView *completionsTableView;

@property(nonatomic,retain) ZulipAppDelegate *delegate;
@property(nonatomic,retain) NSString *type;
@property (nonatomic, retain) NSMutableArray *entryFields;
@property (nonatomic, strong) NSDictionary *fullNameLookupDict;
@property (nonatomic, strong) NSSet *streamLookup;
@property (nonatomic, retain) NSArray *completionMatches;

- (id)initWithReplyTo:(RawMessage *)message;
- (id)initWithRecipient:(ZUser *)recipient;

- (IBAction) send;

@end
