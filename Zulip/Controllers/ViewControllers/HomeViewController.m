//
//  HomeViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "HomeViewController.h"
#import "ZulipAPIController.h"

#import "MBProgressHUD.h"

#import <Crashlytics/Crashlytics.h>

@interface HomeViewController ()

@property (nonatomic, assign) long scrollToPointer;

@property (nonatomic, assign) BOOL initiallyPopulating;
@property (nonatomic, assign) BOOL pointerUpdateRequiresRefetch;

@end

@implementation HomeViewController

- (id) init
{
    self = [super init];

    self.scrollToPointer = -1;
    self.initiallyPopulating = YES;
    self.pointerUpdateRequiresRefetch = NO;

    self.operators = [[NarrowOperators alloc] init];
    [self.operators setInHomeView];

    // Watch for pointer updates
    [[ZulipAPIController sharedInstance] addObserver:self
                                          forKeyPath:@"pointer"
                                             options:(NSKeyValueObservingOptionNew |
                                                      NSKeyValueObservingOptionOld)
                                             context:nil];
    return self;
}


- (void)initialPopulate
{
    // Clear any messages first
    if ([self.messages count]) {
        [self clearMessages];
    }

    if (![MBProgressHUD HUDForView:self.view]) {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }

    // Load initial set of messages
    NSDictionary *args = @{@"anchor": @([ZulipAPIController sharedInstance].pointer),
                           @"num_before": @(12),
                           @"num_after": @(0)};
    [[ZulipAPIController sharedInstance] getOldMessages:args narrow:self.operators completionBlock:^(NSArray *messages) {

        if (self.pointerUpdateRequiresRefetch) {
            self.pointerUpdateRequiresRefetch = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self initialPopulate];
            });
            return;
        }

        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [self loadMessages:messages];
        [self initiallyLoadedMessages];

        // If there are more messages that the user hasn't seen yet, load **one** batch and then we'll load more as the user scrolls
        // to the bottom
        if ([self.messages count] == 0)
            return;

        NSLog(@"Loaded %i initial messages", [self.messages count]);
        RawMessage *last = [self.messages lastObject];

        NSLog(@"More messages to load?, last id is %li and max server id is %li",
              [last.messageID longValue],
              [ZulipAPIController sharedInstance].maxServerMessageId);
        if ([last.messageID longValue] < [ZulipAPIController sharedInstance].maxServerMessageId) {
            // More messages to load
            [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                                   before:0
                                                                    after:20
                                                            withOperators:self.operators
                                                          completionBlock:^(NSArray *newerMessages) {
                CLS_LOG(@"Initially loaded forward %i messages!", [newerMessages count]);
                [self loadMessages:newerMessages];
            }];
        }
    }];
}

- (void)resumePopulate
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    RawMessage *latest = [[self messages] lastObject];
    [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[latest.messageID longValue] + 1
                                                           before:0
                                                            after:20
                                                    withOperators:self.operators
                                                  completionBlock:^(NSArray *messages) {
                                                      CLS_LOG(@"Resuming and fetched loaded %i new messages!", [messages count]);

                                                      [self loadMessages:messages];
                                                      [MBProgressHUD hideHUDForView:self.view animated:YES];
                                                  }];
}

- (void)loadMessages:(NSArray *)messages
{
    // Do extra filtering to remove not-in-home-view stream messages here
    // Messages we get out of the DB are already filtered, but we get all messages
    // from the server (since there's no "in home view only" narrow

    NSArray *filtered = [messages filteredArrayUsingPredicate:[self.operators allocAsPredicate]];
    [super loadMessages:filtered];
}


- (void)updatePointer {
    if ([self.tableView.visibleCells count] == 0)
        return;

    // Find the message in the middle of the screen, and that's where
    // our pointer will be updated to
    CGPoint middle = CGPointMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds));
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:middle];
    // If there's no message in the middle, just take the first one
    if (!path) {
        path = [self.tableView indexPathForCell:[self.tableView.visibleCells objectAtIndex:0]];

        // Shouldn't happen, but...
        if (!path) {
            return;
        }
    }

    RawMessage *message = [self.messages objectAtIndex:path.row];

    self.scrollToPointer = [message.messageID longValue];
    [[ZulipAPIController sharedInstance] setPointer:[message.messageID longValue]];
}


- (void)scrollToPointer:(long)newPointer animated:(BOOL)animated
{
    int pointerRowNum = [self rowWithId:newPointer];
    if (pointerRowNum > -1) {
        CLS_LOG(@"Scrolling to pointer %li", newPointer);
        // If the pointer is already in our table, but not visible, scroll to it
        // but don't try to clear and refetch messages.
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath
                                                indexPathForRow:pointerRowNum
                                                inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:animated];
    }
    [[ZulipAPIController sharedInstance] setPointer:newPointer];
}

#pragma mark StreamViewController


- (NSPredicate *)predicate
{
    return [NSPredicate predicateWithFormat:@"( subscription == NIL ) OR ( subscription.in_home_view == YES )"];
}

- (void)initiallyLoadedMessages
{
    long pointer = [[ZulipAPIController sharedInstance] pointer];
//    CLS_LOG(@"Pointer is %li and rowWithID is %i", pointer, [self rowWithId:pointer]);
    if ([self rowWithId:pointer] > -1) {
        CLS_LOG(@"Done with initial load, scrolling to pointer");
        self.initiallyPopulating = NO;
        [self scrollToPointer:pointer animated:NO];
    }
}

#pragma mark - UITableView


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self performSelectorInBackground:@selector(updatePointer) withObject: nil];
}


#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];

    if ([keyPath isEqualToString:@"pointer"]) {
        long old = [[change objectForKey:NSKeyValueChangeOldKey] longValue];
        long new = [[change objectForKey:NSKeyValueChangeNewKey] longValue];

        if (new > old && new > self.scrollToPointer) {

            // It's possible we loaded an old pointer value
            // from our NSUserDefaults on startup, and have received
            // the real user's pointer (after registering for events)
            // In this case we want to throw away the messages we've fetched
            // and instead fetch messages around the real current pointer.
            if (self.initiallyPopulating) {
                self.pointerUpdateRequiresRefetch = YES;
            }

            [self scrollToPointer:new animated:YES];
        }
    }
}

@end
