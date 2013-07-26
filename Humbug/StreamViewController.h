#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "HumbugAppDelegate.h"

@interface StreamViewController : UITableViewController

@property(assign, nonatomic) IBOutlet MessageCell *messageCell;

@property(nonatomic,retain) HumbugAppDelegate *delegate;

-(void)composeButtonPressed;
-(void)initialPopulate;
-(void)reset;
-(int)rowWithId:(int)messageId;

@end
