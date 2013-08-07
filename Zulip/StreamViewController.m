#import "ZulipAppDelegate.h"
#import "ZulipAPIClient.h"
#import "ComposeViewController.h"
#import "UIColor+HexColor.h"
#include "ZulipAPIController.h"

#import "ZUser.h"
#import "RawMessage.h"

#import "AFJSONRequestOperation.h"

@interface StreamViewController ()

@property (nonatomic, retain) RawMessage *topRow;
@property (nonatomic, retain) IBOutlet MessageCell *messageCell;

@property (nonatomic,retain) ZulipAppDelegate *delegate;

@end

@implementation StreamViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    id ret = [super initWithStyle:style];
    self.messages = [[NSMutableArray alloc] init];
    self.msgIds = [[NSMutableSet alloc] init];
    self.topRow = 0;

    // Listen to long polling messages
    [[NSNotificationCenter defaultCenter] addObserverForName:kLongPollMessageNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      NSArray *messages = [[note userInfo] objectForKey:kLongPollMessageData];
                                                      [self handleLongPollMessages:messages];
                                                  }];

    // KVO watch for resume from background
    [[ZulipAPIController sharedInstance] addObserver:self
                                          forKeyPath:@"backgrounded"
                                             options:(NSKeyValueObservingOptionNew |
                                                      NSKeyValueObservingOptionOld)
                                             context:nil];

    return ret;
}

- (void)clearMessages
{
    [self.messages removeAllObjects];
    [self.msgIds removeAllObjects];
    self.topRow = 0;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:@"Zulip"];

    self.delegate = (ZulipAppDelegate *)[UIApplication sharedApplication].delegate;

    UIImage *composeButtonImage = [UIImage imageNamed:@"bullhorn.png"];
    UIButton *composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composeButton setImage:composeButtonImage forState:UIControlStateNormal];
    composeButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40, composeButtonImage.size.height);
    [composeButton addTarget:self action:@selector(composeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposeButton = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    [[self navigationItem] setRightBarButtonItem:uiBarComposeButton];

    UIImage *composePMButtonImage = [UIImage imageNamed:@"user-toolbar.png"];
    UIButton *composePMButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composePMButton setImage:composePMButtonImage forState:UIControlStateNormal];
    composePMButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40, composeButtonImage.size.height);
    [composePMButton addTarget:self action:@selector(composePMButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposePMButton = [[UIBarButtonItem alloc] initWithCustomView:composePMButton];
    [[self navigationItem] setLeftBarButtonItem:uiBarComposePMButton];
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

- (void)initialPopulate
{}

- (void)resumePopulate
{}

#pragma mark - UIScrollView

// We want to load messages **after** the scroll & deceleration is finished.
// Unfortunately, scrollViewDidFinishDecelerating doesn't work, so we use
// this trick from facebook's Three20 library.
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(scrollViewDidEndScrollingAnimation:) withObject:nil afterDelay:0.3];
}


-(void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
//    NSLog(@"WIll end at %f, height is %f", targetContentOffset->y, );
    CGFloat bottom = self.tableView.contentSize.height - CGRectGetHeight(self.tableView.frame);

    CGFloat bottomPrefetchPadding = 100;
    if (targetContentOffset->y + bottomPrefetchPadding >= bottom) {
        [self loadNewerMessages];
    }
}

-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if ([self.tableView contentOffset].y < 0 && [self.messages count] > 0) {
        self.topRow = [self.messages objectAtIndex:0];
        [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[self.topRow.messageID intValue]
                                                               before:15
                                                                after:0
                                                        withOperators:self.operators
                                                      completionBlock:^(NSArray *messages) {
              [self loadMessages: messages];

          }];

        return;
    }

    CGFloat bottom = self.tableView.contentSize.height - CGRectGetHeight(self.tableView.frame);

    CGFloat bottomPrefetchPadding = 100;
    if (self.tableView.contentOffset.y + bottomPrefetchPadding >= bottom) {
        [self loadNewerMessages];
    }
}

- (void)loadNewerMessages
{
    RawMessage *last = [self.messages lastObject];
    if ([last.messageID longValue] < [ZulipAPIController sharedInstance].maxServerMessageId) {
        NSLog(@"Scrolling to bottom and fetching more messages");
        [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                               before:0
                                                                after:40
                                                        withOperators:self.operators
                                                      completionBlock:^(NSArray *newerMessages) {
              NSLog(@"Initially loaded forward %i messages!", [newerMessages count]);
              [self loadMessages:newerMessages];
          }];
    }
}
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.messages count];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [(MessageCell *)cell willBeDisplayed];
}

- (RawMessage *)messageAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.messages objectAtIndex:indexPath.row];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RawMessage *message = [self messageAtIndexPath:indexPath];

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
    RawMessage * message = [self messageAtIndexPath:indexPath];
    return [MessageCell heightForCellWithMessage:message];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                          initWithNibName:@"ComposeViewController"
                                          bundle:nil];

    RawMessage *message = [self messageAtIndexPath:indexPath];
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

#pragma mark - StreamViewController

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

-(int)rowWithId:(int)messageId
{
    NSUInteger i = 0;
    for (i = 0; i < [self.messages count]; i++) {
        RawMessage *message = [self messageAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]];
        if ([message.messageID intValue] == messageId) {
            return i;
        }
    }
    return -1;
}

-(void)loadMessages:(NSArray *)messages
{
    BOOL insertingAtTop = NO;
    CGPoint offset;
    CGFloat height = self.tableView.contentSize.height;

    if ([messages count] > 0) {
        RawMessage *last = [messages lastObject];

//        NSLog(@"Adding %i backlog with last new message; %i", [_batchedInsertingRows count], [lastNewMsg.messageID intValue]);
        if (last && last.messageID < self.topRow.messageID) {
            insertingAtTop = YES;
            [UIView setAnimationsEnabled:NO];
            offset = [self.tableView contentOffset];
        }
    }

    // this block influenced by: http://stackoverflow.com/questions/8180115/nsmutablearray-add-object-with-order
    // we want to do an in-order insert so that whether doing the initial backfill or inserting historical messages as requested,
    // this method doesn't require special booleans or state.
    for (RawMessage *message in messages) {
        if ([self.msgIds containsObject:message.messageID])
            continue;
        else
            [self.msgIds addObject:message.messageID];

        NSUInteger insertionIndex = [self.messages indexOfObject:message
                                                   inSortedRange:(NSRange){0, [self.messages count]}
                                                         options:NSBinarySearchingInsertionIndex
                                                 usingComparator:^(id left, id right) {
           RawMessage *rLeft = (RawMessage *)left;
           RawMessage *rRight = (RawMessage *)right;
           return [rLeft.messageID compare:rRight.messageID];
        }];

        [self.messages insertObject:message atIndex:insertionIndex];

        [message registerForChanges:^(RawMessage *rawMsg) {
            [self rawMessageDidChange:rawMsg];
        }];
    }

    [self.tableView reloadData];

    if (insertingAtTop) {
        // If inserting at top, calculate the pixels height that was inserted, and scroll to the same position
        offset.y = self.tableView.contentSize.height - height;
        [self.tableView setContentOffset:offset];
        [UIView setAnimationsEnabled:YES];

        int peek_height = 20;
        CGRect peek = CGRectMake(0, offset.y - peek_height, self.tableView.bounds.size.width, peek_height);
        [self.tableView scrollRectToVisible:peek animated:YES];
    }
}

- (void)handleLongPollMessages:(NSArray *)messages
{
    NSMutableArray *accepted = [[NSMutableArray alloc] init];
    for (RawMessage *msg in messages) {
        if (self.operators && [self.operators acceptsMessage:msg])
            [accepted addObject:msg];
    }
    [self loadMessages:accepted];
}

#pragma mark - Message Change Observing

- (void)rawMessageDidChange:(RawMessage *)message
{
    NSLog(@"Message changed: %@", message);
    NSUInteger index = [self.messages indexOfObject:message];
    if (index != NSNotFound) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
        MessageCell *cell = (MessageCell *)[self.tableView cellForRowAtIndexPath:path];

        [cell setMessage:message];
    }
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"backgrounded"]) {
        BOOL old = [[change objectForKey:NSKeyValueChangeOldKey] boolValue];
        BOOL new = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

        if (old && !new) {
            [self resumePopulate];
        }
    }
}

@end
