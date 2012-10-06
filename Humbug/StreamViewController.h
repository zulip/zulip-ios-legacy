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

@property(assign) int first;
@property(assign) int last;

@end
