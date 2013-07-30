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

    // Watch for pointer updates
    [[ZulipAPIController sharedInstance] addObserver:self
                                          forKeyPath:@"pointer"
                                             options:(NSKeyValueObservingOptionNew |
                                                      NSKeyValueObservingOptionOld)
                                             context:nil];
    return ret;
}


- (void)updatePointer {
    UITableViewCell *cell = [self.tableView.visibleCells objectAtIndex:0];
    if (!cell)
        return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:[self.tableView.visibleCells objectAtIndex:0]];
    if (!indexPath)
        return;

    ZMessage *message = (ZMessage *)[self.fetchedResultsController objectAtIndexPath:indexPath];

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

#pragma mark - UITableView


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self performSelectorInBackground:@selector(updatePointer) withObject: nil];
}


#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"pointer"]) {
        long old = [[change objectForKey:NSKeyValueChangeOldKey] longValue];
        long new = [[change objectForKey:NSKeyValueChangeNewKey] longValue];

        if (new > old && new > self.scrollToPointer) {
            [self scrollToPointer:new animated:YES];
        }
    }
}

@end
