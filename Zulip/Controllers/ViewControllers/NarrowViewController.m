//
//  NarrowViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "NarrowViewController.h"
#import "ZulipAPIController.h"
#import "StreamComposeView.h"
#import "StreamProgressView.h"
#import "UIView+Layout.h"

typedef enum  {
    // Ugh Obj-C at making enum values globally visible
    NarrowScrollToFirstUnread = 0,
    NarrowScrollToMessageID = 1
} InitialScrollSettings;

@interface NarrowViewController ()

@property (nonatomic, assign) InitialScrollSettings initialScrollSetting;
@property (nonatomic, assign) long scrollMessageID;

@end

@implementation NarrowViewController

- (id)initWithOperators:(NarrowOperators *)operators
{
    self = [super init];

    if (self) {
        self.operators = operators;
        self.initialScrollSetting = NarrowScrollToFirstUnread;
        self.scrollMessageID = -1;

        self.title = self.operators.title;

        if ([self.title isEqualToString:@"Private Messages"]) {
            self.composeView.isPrivate = YES;
        } else {
            self.composeView.defaultRecipient = self.title;
        }

        [self initialPopulate];
    }

    return self;
}

- (void)scrollToMessageID:(long)messageId
{
    int rowToScroll = [self rowWithId:self.scrollMessageID];
    if (rowToScroll > -1) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:rowToScroll inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle animated:NO]; ;
    } else {
        self.initialScrollSetting = NarrowScrollToMessageID;
        self.scrollMessageID = messageId;
    }
}

#pragma mark - StreamViewControllerDelegate

- (void)initialPopulate
{
    // Clear any messages first
    if ([self.messages count]) {
        [self clearMessages];
    }

    self.tableView.tableFooterView = [[StreamProgressView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, [StreamProgressView height])];

    [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                           before:12
                                                            after:0
                                                    withOperators:self.operators
                                                  completionBlock:^(NSArray *messages, BOOL isFinished) {
      NSLog(@"Initially loaded %i messages!", (int)[messages count]);

      [self loadMessages:messages];

      if ([self.messages count] == 0)
          return;

      if (isFinished) {
          self.tableView.tableFooterView = nil;
      }

      // TODO: This is very similar (but not exactly the same as) HomeViewController.m:60
      //       We should find a way to consolidate the ugly loadMessageAroundAnchor: method call
      RawMessage *last = [self.messages lastObject];
      if ([last.messageID longValue] < [ZulipAPIController sharedInstance].maxServerMessageId) {
          // More messages to load
          [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                                 before:0
                                                                  after:20
                                                          withOperators:self.operators
                                                        completionBlock:^(NSArray *newerMessages, BOOL isFinishedLoading) {
            NSLog(@"Initially loaded forward %i messages!", (int)[newerMessages count]);
            [self loadMessages:newerMessages];
            [self newMessagesLoaded];
        }];
      } else {
          [self newMessagesLoaded];
      }


      [self newMessagesLoaded];
    }];
}

- (void)resumePopulate
{
}

- (NSIndexPath *)indexOfFirstUnread
{
    NSIndexPath *unread = nil;
    for (NSUInteger i = 0; i < [self.messages count]; i++) {
        RawMessage *msg = [self.messages objectAtIndex:i];
        if (![msg read]) {
            unread = [NSIndexPath indexPathForRow:i inSection:0];
            break;
        }
    }
    return unread;
}

- (NSIndexPath *)indexOfScrollToMessage:(long)messageID
{
    int rowToScroll = [self rowWithId:self.scrollMessageID];
    if (rowToScroll == -1) {
        NSLog(@"Narrow initially loaded messages but DID NOT FIND scroll-to message id %li", self.scrollMessageID);
        return nil;
    }
    return[NSIndexPath indexPathForRow:rowToScroll inSection:0];
}

- (void)newMessagesLoaded
{
    if ([self.messages count] == 0) {
        return;
    }

    NSIndexPath *target = nil;
    if (self.initialScrollSetting == NarrowScrollToFirstUnread) {
        target = [self indexOfFirstUnread];
    } else if (self.initialScrollSetting == NarrowScrollToMessageID &&
               self.scrollMessageID > -1) {
        target = [self indexOfScrollToMessage:self.scrollMessageID];
    } else {
        NSLog(@"New messages loaded in narrow but BAD scroll data!");
        return;
    }

    if (!target) {
        target = [NSIndexPath indexPathForRow:[self.messages count] - 1 inSection:0];
    }
    // Scroll to desired message in the middle of the screen
    NSLog(@"Scrolling to desired row on narrow, with setting %i and target %@", self.initialScrollSetting, target);
    [self.tableView scrollToRowAtIndexPath:target atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

@end
