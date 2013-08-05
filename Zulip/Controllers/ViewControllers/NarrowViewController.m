//
//  NarrowViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "NarrowViewController.h"
#import "ZulipAPIController.h"

@interface NarrowViewController ()

@end

@implementation NarrowViewController

- (id)initWithOperators:(NarrowOperators *)operators
{
    self = [super init];

    if (self) {
        self.operators = operators;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initialPopulate];
}

#pragma mark - StreamViewControllerDelegate

- (void)initialPopulate
{
    // Clear any messages first
    if ([self.messages count]) {
        [self clearMessages];
    }

    [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                           before:12
                                                            after:0
                                                    withOperators:self.operators
                                                             opts:@{}
                                                  completionBlock:^(NSArray *messages) {
                                                      NSLog(@"Initially loaded %i messages!", [messages count]);

                                                      [self loadMessages:messages];
                                                      [self initiallyLoadedMessages];
                                                  }];
}

- (void)resumePopulate
{
    NSLog(@"Resuming populating!");
}


- (void)initiallyLoadedMessages
{
    NSIndexPath *unread = nil;
    for (NSUInteger i = 0; i < [self.messages count]; i++) {
        RawMessage *msg = [self.messages objectAtIndex:i];
        if (![msg read]) {
            unread = [NSIndexPath indexPathForRow:i inSection:0];
            break;
        }
    }
    if (!unread) {
        unread = [NSIndexPath indexPathForRow:[self.messages count] - 1 inSection:0];
    }
    // Scroll to first unread in the middle of the screen
    NSLog(@"Scrolling to : %@", unread);
    [self.tableView scrollToRowAtIndexPath:unread atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

@end
