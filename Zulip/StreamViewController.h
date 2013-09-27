#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "NarrowOperators.h"

//@protocol StreamViewControllerDelegate <NSObject>

//- (NSPredicate *)filterPrediate;
//- ()

//@end

@interface StreamViewController : UITableViewController <MessageCellDelegate>

@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) NSMutableSet *msgIds;
@property (nonatomic, retain) NarrowOperators *operators;

// Generic message list implementations
- (int)rowWithId:(int)messageId;

- (void)initialPopulate;
- (void)resumePopulate;
- (void)clearMessages;

- (void)loadMessages:(NSArray *)messages;

@end
