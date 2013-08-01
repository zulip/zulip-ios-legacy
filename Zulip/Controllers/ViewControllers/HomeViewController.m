//
//  HomeViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "HomeViewController.h"
#import "ZulipAPIController.h"

@interface HomeViewController ()

@property(assign) BOOL initialLoad;
@property(assign) long scrollToPointer;

@end

@implementation HomeViewController

- (id) init
{
    id ret = [super init];

    self.initialLoad = YES;
    self.scrollToPointer = -1;

    self.operators = [[NarrowOperators alloc] init];
    [self.operators setInHomeView];

    // Watch for pointer updates
    [[ZulipAPIController sharedInstance] addObserver:self
                                          forKeyPath:@"pointer"
                                             options:(NSKeyValueObservingOptionNew |
                                                      NSKeyValueObservingOptionOld)
                                             context:nil];
    return ret;
}


- (void)initialPopulate
{
    // Clear any messages first
    if ([self.messages count]) {
        [self clearMessages];
    }

    // Load initial set of messages
    NSLog(@"Initially populating!");
    [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                           before:12
                                                            after:0
                                                    withOperators:nil
                                                             opts:@{@"fetch_until_latest": @(YES)}
                                                  completionBlock:^(NSArray *messages) {
                                                      NSLog(@"Initially loaded %i messages!", [messages count]);

                                                      [self loadMessages:messages];
                                                  }];
}

- (void)resumePopulate
{
    NSLog(@"Resuming populating!");
    RawMessage *latest = [[self messages] lastObject];
    [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[latest.messageID intValue] + 1
                                                           before:0
                                                            after:20
                                                    withOperators:nil
                                                             opts:@{}
                                                  completionBlock:^(NSArray *messages) {
                                                      NSLog(@"Resuming and fetched loaded %i new messages!", [messages count]);

                                                      [self loadMessages:messages];
                                                  }];
}


- (void)updatePointer {
    if ([self.tableView.visibleCells count] == 0)
        return;

    UITableViewCell *cell = [self.tableView.visibleCells objectAtIndex:0];
    if (!cell)
        return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:[self.tableView.visibleCells objectAtIndex:0]];
    if (!indexPath)
        return;

    RawMessage *message = [self.messages objectAtIndex:indexPath.row];

    self.scrollToPointer = [message.messageID longValue];
    [[ZulipAPIController sharedInstance] setPointer:[message.messageID longValue]];
}


- (void)scrollToPointer:(long)newPointer animated:(BOOL)animated
{
    int pointerRowNum = [self rowWithId:newPointer];
    if (pointerRowNum > -1) {
        NSLog(@"Scrolling to pointer %li", newPointer);
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

- (void)messagesDidChange
{
    long pointer = [[ZulipAPIController sharedInstance] pointer];
//    NSLog(@"Pointer is %li and rowWithID is %i", pointer, [self rowWithId:pointer]);
    if (self.initialLoad && [self rowWithId:pointer] > -1) {
        self.initialLoad = NO;
        NSLog(@"Done with initial load, scrolling to pointer");
        [self scrollToPointer:pointer animated:NO];
    }
}

- (BOOL)acceptsMessage:(RawMessage *)message
{
    return message.subscription && [message.subscription.in_home_view boolValue];
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
            [self scrollToPointer:new animated:YES];
        }
    }
}

@end
