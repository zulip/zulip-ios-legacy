#import <UIKit/UIKit.h>
#import "MessageCell.h"

@interface StreamViewController : UITableViewController

// Generic message list implementations
- (void)composeButtonPressed;
- (void)menuButtonPressed;
- (void)initialPopulate;
- (int)rowWithId:(int)messageId;

@property(nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

@end
