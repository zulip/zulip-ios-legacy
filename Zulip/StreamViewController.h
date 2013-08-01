#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "NarrowOperators.h"

//@protocol StreamViewControllerDelegate <NSObject>

//- (NSPredicate *)filterPrediate;
//- ()

//@end

@interface StreamViewController : UITableViewController

@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) NSMutableSet *msgIds;
@property (nonatomic, retain) NarrowOperators *operators;

// Generic message list implementations
- (void)composeButtonPressed;
- (int)rowWithId:(int)messageId;

// The NSPredicate * to use for this message list
// Implement in subclass
// TODO create a proper protocol
//- (NSPredicate *);
//- (BOOL)acceptsMessage:(RawMessage *);

- (void)initialPopulate;
- (void)resumePopulate;
- (void)clearMessages;

-(void)loadMessages:(NSArray *)messages;

@end
