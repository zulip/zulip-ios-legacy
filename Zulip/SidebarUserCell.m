//
//  SidebarUserCell.m
//  Zulip
//
//  Created by Michael Walker on 12/29/13.
//
//

#import "SidebarUserCell.h"
#import "ZUser.h"
#import "ZulipAPIController.h"
#import "ZUserPresence.h"
#import "UIColor+HexColor.h"

@implementation SidebarUserCell

- (void)layoutSubviews {
    self.statusIcon.layer.cornerRadius = CGRectGetWidth(self.statusIcon.frame)/2;
}

- (void)setUser:(ZUser *)user {
    _user = user;
    self.name.text = user.full_name;
    [self calculateUnreadCount];
}

- (void)calculateUnreadCount {
    NSDictionary *unread_counts = [[[ZulipAPIController sharedInstance] unreadManager] unreadCounts];

    NSUInteger unread = [unread_counts[self.user.email] integerValue];
    [self setCount:unread];
}

- (void)setStatus:(NSString *)status {
    self.statusIcon.layer.borderWidth = 0;
    
    if ([status isEqualToString:ZUserPresenceStatusActive]) {
        self.statusIcon.backgroundColor = [UIColor colorWithHexString:@"#44c21d" defaultColor:UIColor.clearColor];
    } else if ([status isEqualToString:ZUserPresenceStatusIdle]) {
        self.statusIcon.backgroundColor = [UIColor colorWithHexString:@"#ec7e18" defaultColor:UIColor.clearColor];
    } else { // ZUserPresenceStatusOffline
        self.statusIcon.backgroundColor = UIColor.clearColor;
        self.statusIcon.layer.borderWidth = 1.f;
        self.statusIcon.layer.borderColor = UIColor.grayColor.CGColor;
    }
}

- (void)setCount:(NSInteger)count
{
    if (count > 0) {
        self.unreadCount.text = [NSString stringWithFormat:@"%i", (int)count];
    } else {
        self.unreadCount.text = @"";
    }
}

@end
