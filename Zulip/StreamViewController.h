#import <UIKit/UIKit.h>
#import "MessageCell.h"

@interface StreamViewController : UITableViewController

// Generic message list implementations
- (void)composeButtonPressed;
- (void)menuButtonPressed;
- (void)initialPopulate;
- (int)rowWithId:(int)messageId;

// The NSPredicate * to use for this message list
// Implement in subclass
// TODO create a proper protocol
//- (NSPredicate *)predicate;

@property(nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

@end
