#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "NarrowOperators.h"
#import "MessageComposing.h"

@class StreamComposeView;
@class ZUser;

//@protocol StreamViewControllerDelegate <NSObject>

//- (NSPredicate *)filterPrediate;
//- ()

//@end

@interface StreamViewController : UIViewController <MessageCellDelegate, UITableViewDataSource, UITableViewDelegate, MessageComposing>

@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) NSMutableSet *msgIds;
@property (nonatomic, retain) NarrowOperators *operators;

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (strong, nonatomic) StreamComposeView *composeView;

// Generic message list implementations
- (int)rowWithId:(int)messageId;

- (void)initialPopulate;
- (void)resumePopulate;
- (void)clearMessages;

- (void)loadMessages:(NSArray *)messages;

@end
