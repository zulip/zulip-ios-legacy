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
    NarrowOperators *op = [[NarrowOperators alloc] init];

    switch (shortcut) {
        case HOME:
            self.name.text = @"Home";
            // Magic to go  back to the main view
            [op setInHomeView];
            break;

        case PRIVATE_MESSAGES:
            self.name.text = @"Private Messages";
            [op setPrivateMessages];
        default:
            break;
    }
    _narrow = op;
}

- (void)setStream:(ZSubscription *)subscription
{
    _shortcut = STREAM;
    _stream = subscription;
    self.name.text = subscription.name;

    NarrowOperators *op = [[NarrowOperators alloc] init];
    [op addStreamNarrow:subscription.name];
    _narrow = op;
}

@end
