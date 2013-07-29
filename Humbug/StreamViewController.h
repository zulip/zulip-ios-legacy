#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "HumbugAppDelegate.h"

@interface StreamViewController : UITableViewController

@property(assign, nonatomic) IBOutlet MessageCell *messageCell;

@property(nonatomic,retain) HumbugAppDelegate *delegate;
@property(nonatomic,retain) NSDictionary *streams;


@property(assign) BOOL waitingOnErrorRecovery;
@property(assign) double timeWhenBackgrounded;
@property(assign) BOOL backgrounded;

-(void)composeButtonPressed;
-(void)initialPopulate;
-(void)reset;
-(int)rowWithId:(int)messageId;

+ (UIColor *)defaultStreamColor;

@end
