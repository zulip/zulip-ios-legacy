#import <UIKit/UIKit.h>
#import "MessageCell.h"
#import "HumbugAppDelegate.h"

@interface StreamViewController : UITableViewController {
    NSMutableArray *listData;
    NSMutableData *responseData;
    NSMutableDictionary *gravatars;
}

@property(assign, nonatomic) IBOutlet MessageCell *messageCell;

@property(nonatomic,retain) NSMutableArray *listData;
@property(nonatomic,retain) NSMutableDictionary *gravatars;
@property(nonatomic,retain) HumbugAppDelegate *delegate;
@property(nonatomic,retain) NSDictionary *streams;

@property(assign) int first;
@property(assign) int last;
@property(assign) double lastRequestTime;
@property(assign) BOOL pollingStarted;
@property(assign) double backoff;
@property(assign) BOOL waitingOnErrorRecovery;
@property(assign) double timeWhenBackgrounded;
@property(assign) BOOL backgrounded;

-(void)composeButtonPressed;
-(void)initialPopulate;
-(void)reset;
-(int)rowWithId:(int)messageId;

+ (UIColor *)defaultStreamColor;

@end
