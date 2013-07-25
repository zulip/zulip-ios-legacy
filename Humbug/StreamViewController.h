#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "HumbugAppDelegate.h"

@interface StreamViewController : UITableViewController

@property(assign, nonatomic) IBOutlet MessageCell *messageCell;

// listData is the data delegate for our home message list
@property(nonatomic,retain) NSMutableArray *listData;
// allMessages contains all known messages, even not-in-home-view ones
@property(nonatomic,retain) NSMutableArray *allMessages;
@property(nonatomic, retain) NSMutableSet *messageIDs;
@property(nonatomic,retain) HumbugAppDelegate *delegate;
@property(nonatomic,retain) NSDictionary *streams;

// User-specific info from the server
@property(assign) int lastEventId;
@property(assign) int maxMessageId;
@property(assign) long pointer;
@property(nonatomic, retain) NSString *queueId;

// Internally used variables
@property(assign) double lastRequestTime;
@property(assign) int pollFailures;
@property(assign) BOOL pollingStarted;
@property(assign) double backoff;
@property(assign) BOOL waitingOnErrorRecovery;
@property(assign) double timeWhenBackgrounded;
@property(assign) BOOL backgrounded;

-(void)composeButtonPressed;
-(void)menuButtonPressed;
-(void)initialPopulate;
-(void)reset;
-(int)rowWithId:(int)messageId;

+ (UIColor *)defaultStreamColor;

@end
