#import "ZulipAppDelegate.h"
#import "ZulipAPIClient.h"
#import "ComposeViewController.h"
#import "UIColor+HexColor.h"
#include "ZulipAPIController.h"

#import "ZMessage.h"
#import "ZUser.h"

#import "AFJSONRequestOperation.h"

@interface StreamViewController () <NSFetchedResultsControllerDelegate> {
    // NSFetchedResultsController helpers
    NSMutableArray *_batchedInsertingRows;
}

@property(assign, nonatomic) IBOutlet MessageCell *messageCell;

@property(nonatomic,retain) ZulipAppDelegate *delegate;

@property(nonatomic, assign) BOOL currentlyIgnoringScrollPastTopEvents;
@property(nonatomic, retain) ZMessage* topRow;
@property(assign) CGFloat scrollFinalTarget;


- (void)refetchData;

@end

@implementation StreamViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    id ret = [super initWithStyle:style];
    self.fetchedResultsController = 0;

    return ret;
}

- (void)refetchData {
    // Refetches all our messages
    [self.fetchedResultsController performSelectorOnMainThread:@selector(performFetch:) withObject:nil waitUntilDone:YES modes:@[ NSRunLoopCommonModes ]];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:@"Zulip"];

    self.delegate = (ZulipAppDelegate *)[UIApplication sharedApplication].delegate;

    UIImage *composeButtonImage = [UIImage imageNamed:@"glyphicons_355_bullhorn.png"];
    UIButton *composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composeButton setImage:composeButtonImage forState:UIControlStateNormal];
    composeButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40,
                                     composeButtonImage.size.height);
    [composeButton addTarget:self action:@selector(composeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposeButton = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    [[self navigationItem] setRightBarButtonItem:uiBarComposeButton];

    UIImage *composePMButtonImage = [UIImage imageNamed:@"glyphicons_003_user.png"];
    UIButton *composePMButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composePMButton setImage:composePMButtonImage forState:UIControlStateNormal];
    composePMButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40,
                                       composeButtonImage.size.height);
    [composePMButton addTarget:self action:@selector(composePMButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposePMButton = [[UIBarButtonItem alloc] initWithCustomView:composePMButton];
    [[self navigationItem] setLeftBarButtonItem:uiBarComposePMButton];

    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [menuButton setTitle:@"Zulip" forState:UIControlStateNormal];
    [menuButton setTitleColor:[UIColor colorWithWhite:1 alpha:1] forState:UIControlStateNormal];
    [menuButton addTarget:self action:@selector(menuButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [[self navigationItem] setTitleView:menuButton];

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

#pragma mark - UIScrollView

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    NSUInteger numRows = [self tableView:self.tableView numberOfRowsInSection:0];

    self.currentlyIgnoringScrollPastTopEvents = NO;
    if ((targetContentOffset->y < 200) && !self.currentlyIgnoringScrollPastTopEvents && (numRows > 5)){
        self.currentlyIgnoringScrollPastTopEvents = YES;
        self.scrollFinalTarget = targetContentOffset->y;
        // Load old messages, with the anchor set to whatever is at the top of the StreamView UITable
        self.topRow = (ZMessage *)[self.fetchedResultsController objectAtIndexPath:[self invertIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]]];
        NSLog(@"Getting more with anchor: %@", self.topRow.messageID);

        [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[self.topRow.messageID intValue] before:15 after:0];
    }
    return;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [(MessageCell *)cell willBeDisplayed];
}

- (ZMessage *)messageAtIndexPath:(NSIndexPath *)indexPath
{
    indexPath = [self invertIndexPath:indexPath];
    @try {
        return (ZMessage *)[self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception: %@", exception);
        return nil;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView
        cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ZMessage *message = [self messageAtIndexPath:indexPath];

    MessageCell *cell = (MessageCell *)[self.tableView dequeueReusableCellWithIdentifier:
                                        [MessageCell reuseIdentifier]];
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"MessageCellView" owner:self options:nil];
        cell = self.messageCell;
        self.messageCell = nil;
    }

    [cell setMessage:message];

    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ZMessage * message = [self messageAtIndexPath:indexPath];
    return [MessageCell heightForCellWithMessage:message];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                          initWithNibName:@"ComposeViewController"
                                          bundle:nil];

    ZMessage *message = [self messageAtIndexPath:indexPath];
    composeView.type = message.type;
    [[self navigationController] pushViewController:composeView animated:YES];

    if ([message.type isEqualToString:@"stream"]) {
        composeView.recipient.text = message.stream_recipient;
        [composeView.subject setHidden:NO];
        composeView.subject.text = message.subject;
    } else if ([message.type isEqualToString:@"private"]) {
        [composeView.subject setHidden:YES];

        NSSet *recipients = message.pm_recipients;
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (ZUser *recipient in recipients) {
            if (![recipient.email isEqualToString:[[ZulipAPIController sharedInstance] email]]) {
                [recipient_array addObject:recipient.email];
            }
        }
        composeView.privateRecipient.text = [recipient_array componentsJoinedByString:@", "];
    }
}

/*
 HACK this is a workaround for us not being able to do the proper Core Data query that we want.
 We are not able to say "give me the last X messages in ascending order. We can only do:

 * First X messages in ascending oder
 * Last X messages in descending order

 and since we want to limit how many messages we initially fetch, we do the latter.

 However, this means the message list we get out of core data (and that is stored in
 NSFetchedResultsController) is in the wrong order. We invert the indices, so undo
 the incorrect ordering
 */
- (NSIndexPath *)invertIndexPath:(NSIndexPath *)path
{
    int count = [[[self.fetchedResultsController sections] objectAtIndex:0] numberOfObjects];
    NSIndexPath *fixed = [NSIndexPath indexPathForRow:(count - path.row - 1) inSection:path.section];
    return fixed;
}

#pragma mark - StreamViewController

- (void)initialPopulate
{
    if (self.fetchedResultsController) {
        self.fetchedResultsController = 0;
    }

    // This is the home view, so we want to display all messages
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZMessage"];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"messageID" ascending:NO]];
    fetchRequest.fetchOffset = 0; // 0 offset + descending means starting from the end
    fetchRequest.fetchBatchSize = 15;

    // We only want stream messages that have the in_home_view flag set in the associated subscription object
    if ([self respondsToSelector:@selector(predicate)])
        fetchRequest.predicate = [self performSelector:@selector(predicate)];

    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:[self.delegate managedObjectContext]
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:@"AllMessages"];
    self.fetchedResultsController.delegate = self;
    // Load initial set of messages
    NSLog(@"Initially populating!");
    [self refetchData];
    [self.tableView reloadData];
}

-(void)composeButtonPressed {
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                    initWithNibName:@"ComposeViewController"
                                    bundle:nil];
    composeView.type = @"stream";
    [[self navigationController] pushViewController:composeView animated:YES];
}

-(void)composePMButtonPressed {
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                     initWithNibName:@"ComposeViewController"
                                     bundle:nil];
    composeView.type = @"private";
    [[self navigationController] pushViewController:composeView animated:YES];
}

-(void)menuButtonPressed {
    LoginViewController *menuView = [[LoginViewController alloc] initWithNibName:@"LoginViewController"
                                                                          bundle:nil];
    [[self navigationController] pushViewController:menuView animated:YES];
}

-(int) rowWithId: (int)messageId
{
    int i = 0;
    for (i = 0; i < [[[self.fetchedResultsController sections] objectAtIndex:0] numberOfObjects]; i++) {
        ZMessage *message = [self messageAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]];
        if ([message.messageID intValue] == messageId) {
            return i;
        }
    }
    return -1;
}

-(void)repopulateList
{
    [self initialPopulate];
}

#pragma mark - NSFetchedResultsControllerDelegate methods
// Below code mostly inspired by Apple documentation on NSFetchedResultsControllerDelegate
/*
 Assume self has a property 'tableView' -- as is the case for an instance of a UITableViewController
 subclass -- and a method configureCell:atIndexPath: which updates the contents of a given cell
 with information from a managed object at the given index path in the fetched results controller.
 */

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
//    [self.tableView beginUpdates];

    _batchedInsertingRows = [[NSMutableArray alloc] init];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {

    UITableView *tableView = self.tableView;

    switch(type) {

        case NSFetchedResultsChangeInsert:
//            NSLog(@"Added object: %@", newIndexPath);
            // Batch inserting rows
            [_batchedInsertingRows addObject:newIndexPath];

//            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
//                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
//            NSLog(@"Removed object: %@", newIndexPath);

            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
        {
//            NSLog(@"Changed object: %i", [newIndexPath row]);
            MessageCell *cell = (MessageCell *)[self.tableView cellForRowAtIndexPath:newIndexPath];
            ZMessage *message = [self messageAtIndexPath:newIndexPath];

            [cell setMessage:message];
            break;
        }
        case NSFetchedResultsChangeMove:
//            NSLog(@"Moved object: from %i to %i", [indexPath row], [newIndexPath row]);

            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    BOOL insertingAtTop = NO;

    if ([_batchedInsertingRows count] > 0) {
        NSIndexPath *last = [_batchedInsertingRows lastObject];
        ZMessage *lastNewMsg = (ZMessage *)[self.fetchedResultsController objectAtIndexPath:last];

        NSLog(@"Adding %i backlog with last new message; %i", [_batchedInsertingRows count], [lastNewMsg.messageID intValue]);
        if (lastNewMsg && lastNewMsg.messageID < self.topRow.messageID) {
            insertingAtTop = YES;
        }

//        [self.tableView insertRowsAtIndexPaths:_batchedInsertingRows withRowAnimation:UITableViewRowAnimationFade];

        [_batchedInsertingRows removeAllObjects];
    }

//    [self.tableView endUpdates];
    [self.tableView reloadData];

    if ([self respondsToSelector:@selector(messagesDidChange)]) {
        [self performSelector:@selector(messagesDidChange)];
    }
}

@end
