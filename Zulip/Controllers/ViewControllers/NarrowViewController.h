//
//  NarrowViewController.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import <UIKit/UIKit.h>
#import "StreamViewController.h"
#import "NarrowOperators.h"

@interface NarrowViewController : StreamViewController

- (id)initWithOperators:(NarrowOperators *)operators;

// Default behaviour is to scroll to first unread
// This will attempt to scroll to the desired message ID
// when loaded if the message is not yet loaded
- (void)scrollToMessageID:(long)messageId;

@end
