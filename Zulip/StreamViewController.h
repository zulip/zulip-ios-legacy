#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "NarrowOperators.h"

@class StreamComposeView;

//@protocol StreamViewControllerDelegate <NSObject>

//- (NSPredicate *)filterPrediate;
//- ()

//@end

@interface StreamViewController : UIViewController <MessageCellDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, retain) NSMutableArray *messages;
@property (nonatomic, retain) NSMutableSet *msgIds;
@property (nonatomic, retain) NarrowOperators *operators;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet StreamComposeView *composeView;

// Generic message list implementations
- (int)rowWithId:(int)messageId;

- (void)initialPopulate;
- (void)resumePopulate;
- (void)clearMessages;

- (void)loadMessages:(NSArray *)messages;

@end
