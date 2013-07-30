//
//  SidebarStreamCell.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "SidebarStreamCell.h"
#import "ZulipAPIController.h"

@interface SidebarStreamCell ()

@end

@implementation SidebarStreamCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.stream = nil;
    }
    return self;
}

- (void)setShortcut:(SIDEBAR_SHORTCUTS)shortcut
{
    _shortcut = shortcut;
    switch (shortcut) {
        case HOME:
            self.name.text = @"Home";
            // Magic to go  back to the main view
            break;

        case PRIVATE_MESSAGES:
            self.name.text = @"Private Messages";
            _predicate = [NSPredicate predicateWithFormat:@"subscription == nil"];
        default:
            break;
    }
}

- (void)setStream:(ZSubscription *)subscription
{
    _shortcut = STREAM;
    _stream = subscription;
    self.name.text = subscription.name;

    _predicate = [NSPredicate predicateWithFormat:@"subscription.name LIKE %@", subscription.name];
}

@end
