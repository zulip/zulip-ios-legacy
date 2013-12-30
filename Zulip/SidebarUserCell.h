//
//  SidebarUserCell.h
//  Zulip
//
//  Created by Michael Walker on 12/29/13.
//
//

@class ZUser;

#import <UIKit/UIKit.h>

@interface SidebarUserCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIView *statusIcon;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *unreadCount;

@property (strong, nonatomic) ZUser *user;
@property (strong, nonatomic) NSString *status;

- (void)calculateUnreadCount;

@end
