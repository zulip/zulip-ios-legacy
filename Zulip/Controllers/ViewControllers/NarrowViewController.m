//
//  NarrowViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "NarrowViewController.h"
#import "ZulipAPIController.h"

#import <Crashlytics/Crashlytics.h>

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

    self.title = self.operators.title;
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
                                                  completionBlock:^(NSArray *messages) {
      CLS_LOG(@"Initially loaded %i messages!", [messages count]);

      [self loadMessages:messages];

      if ([self.messages count] == 0)
          return;

      // TODO: This is very similar (but not exactly the same as) HomeViewController.m:60
      //       We should find a way to consolidate the ugly loadMessageAroundAnchor: method call
      RawMessage *last = [self.messages lastObject];
      if ([last.messageID longValue] < [ZulipAPIController sharedInstance].maxServerMessageId) {
          // More messages to load
          [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                                 before:0
                                                                  after:20
                                                          withOperators:self.operators
                                                        completionBlock:^(NSArray *newerMessages) {
            CLS_LOG(@"Initially loaded forward %i messages!", [newerMessages count]);
            [self loadMessages:newerMessages];
            [self initiallyLoadedMessages];
        }];
      } else {
          [self initiallyLoadedMessages];
      }


      [self initiallyLoadedMessages];
    }];
}

- (void)resumePopulate
{
}


- (void)initiallyLoadedMessages
{
    if ([self.messages count] == 0) {
        return;
    }

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
    CLS_LOG(@"Scrolling to row %i", [unread row]);
    [self.tableView scrollToRowAtIndexPath:unread atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

@end
