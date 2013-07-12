#import "FirstViewController.h"
#import "HumbugAppDelegate.h"
#import "HumbugAPIClient.h"
#import "ComposeViewController.h"
#import "UIColor+HexColor.h"

#import "AFJSONRequestOperation.h"
#import "UIImageView+AFNetworking.h"

@implementation StreamViewController
@synthesize allMessages;
@synthesize listData;
@synthesize messageCell = _messageCell;
@synthesize lastEventId, maxMessageId, pointer, queueId;
@synthesize delegate;
@synthesize lastRequestTime;
@synthesize waitingOnErrorRecovery;
@synthesize timeWhenBackgrounded;
@synthesize streams;

- (id)initWithStyle:(UITableViewStyle)style
{
    return [super initWithStyle:style];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:@"Humbug"];
    self.pointer = -1;
    self.lastEventId = -1;
    self.maxMessageId = -1;
    self.backoff = 0;
    self.queueId = @"";
    self.lastRequestTime = 0;
    self.pollFailures = 0;
    self.backgrounded = FALSE;
    self.pollingStarted = FALSE;
    self.waitingOnErrorRecovery = FALSE;
    self.listData = [[NSMutableArray alloc] init];
    self.allMessages = [[NSMutableArray alloc] init];
    self.delegate = (HumbugAppDelegate *)[UIApplication sharedApplication].delegate;
    
    UIImage *composeButtonImage = [UIImage imageNamed:@"glyphicons_355_bullhorn.png"];
    UIButton *composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composeButton setImage:composeButtonImage forState:UIControlStateNormal];
    composeButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40,
                                     composeButtonImage.size.height);
    [composeButton addTarget:self action:@selector(composeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposeButton = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    [[self navigationItem] setRightBarButtonItem:uiBarComposeButton];
    [composeButton release];
    
    UIImage *composePMButtonImage = [UIImage imageNamed:@"glyphicons_003_user.png"];
    UIButton *composePMButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composePMButton setImage:composePMButtonImage forState:UIControlStateNormal];
    composePMButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40,
                                       composeButtonImage.size.height);
    [composePMButton addTarget:self action:@selector(composePMButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposePMButton = [[UIBarButtonItem alloc] initWithCustomView:composePMButton];
    [[self navigationItem] setLeftBarButtonItem:uiBarComposePMButton];
    [composePMButton release];
    [uiBarComposePMButton release];
}

- (void)viewDidAppear:(BOOL)animated
{
    // This function gets called whenever the stream view appears, including returning to the view after popping another view. We only want to backfill old messages on the very first load.
    [self initialPopulate];
}

- (void)loadSubscriptionData:(NSArray *)subscriptions
{
    NSMutableDictionary *streamdict = [[NSMutableDictionary alloc] init];
    for (NSDictionary* stream in subscriptions) {
        [streamdict setObject:stream forKey:[stream objectForKey:@"name"]];
    }
    [self setStreams:streamdict];
}

- (void)initialPopulate
{
    if (self.maxMessageId == -1) {
        // Register for events, then fetch messages
        [[HumbugAPIClient sharedClient] postPath:@"register" parameters:[NSDictionary dictionaryWithObjectsAndKeys:@"false", @"apply_markdown", nil]
        success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSDictionary *json = (NSDictionary *)responseObject;

            NSArray *subscriptions = [json objectForKey:@"subscriptions"];
            [self loadSubscriptionData:subscriptions];

            self.queueId = [json objectForKey:@"queue_id"];
            self.lastEventId = [[json objectForKey:@"last_event_id"] intValue];
            self.maxMessageId = [[json objectForKey:@"max_message_id"] intValue];
            self.pointer = [[json objectForKey:@"pointer"] longValue];

            // Load old messages
            NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInteger:12], @"num_before",
                                   [NSNumber numberWithInteger:0], @"num_after",
                                   [NSNumber numberWithBool:YES], @"scroll_to_pointer",
                                   nil];
            [self getOldMessages:args];
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Failure doing initialPopulate...retrying %@", [error localizedDescription]);

            [self performSelector:@selector(initialPopulate) withObject:self afterDelay:1];
        }];
    }
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

    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(NSInteger)tableView:(UITableView *)tableView
numberOfRowsInSection:(NSInteger)section
{
    return [self.listData count];
}

+ (UIColor *)defaultStreamColor {
    return [UIColor colorWithRed:187.0/255
                           green:187.0/255
                            blue:187.0/255
                           alpha:1];
}

- (NSURL *)gravatarUrl:(NSString *)gravatarHash
{
    return [NSURL URLWithString:
            [NSString stringWithFormat:
             @"https://secure.gravatar.com/avatar/%@?d=identicon&s=30",
             gravatarHash]];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    MessageCell *my_cell = (MessageCell *)cell;
    if ([my_cell.type isEqualToString:@"stream"]) {
        my_cell.headerBar.backgroundColor = [self streamColor:my_cell.recipient];
    } else {
        // For non-stream messages, color cell background pale yellow (#FEFFE0).
        my_cell.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255
                                                   blue:224.0/255 alpha:1];
        my_cell.headerBar.backgroundColor = [UIColor colorWithRed:51.0/255
                                                            green:51.0/255
                                                             blue:51.0/255
                                                            alpha:1];
        my_cell.header.textColor = [UIColor whiteColor];
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView
        cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = [indexPath row];
    NSDictionary *dict = [listData objectAtIndex:row];

    MessageCell *cell = (MessageCell *)[self.tableView dequeueReusableCellWithIdentifier:
                                        [MessageCell reuseIdentifier]];
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"MessageCellView" owner:self options:nil];
        cell = _messageCell;
        _messageCell = nil;
    }

    cell.type = [dict objectForKey:@"type"];
    cell.recipient = [dict objectForKey:@"display_recipient"];
    if ([cell.type isEqualToString:@"stream"]) {
        cell.header.text = [NSString stringWithFormat:@"%@ > %@",
                            [dict objectForKey:@"display_recipient"],
                            [dict objectForKey:@"subject"]];
    } else if ([cell.type isEqualToString:@"private"]) {
        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (NSDictionary *recipient in recipients) {
            if (![[recipient valueForKey:@"email"] isEqualToString:self.delegate.email]) {
                [recipient_array addObject:[recipient objectForKey:@"full_name"]];
            }
        }
        cell.header.text = [@"You and " stringByAppendingString:[recipient_array componentsJoinedByString:@", "]];
    }

    cell.sender.text = [dict objectForKey:@"sender_full_name"];
    cell.content.text = [dict objectForKey:@"content"];
    // Allow multi-line content.
    cell.content.lineBreakMode = UILineBreakModeWordWrap;
    cell.content.numberOfLines = 0;

    // Asynchronously load gravatar if needed
    NSString *ghash = [dict objectForKey:@"gravatar_hash"];
    [cell.gravatar setImageWithURL:[self gravatarUrl:ghash]];

    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]
                              autorelease]];
    [dateFormatter setDateFormat:@"HH:mm"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:
                    [[dict objectForKey:@"timestamp"] doubleValue]];
    cell.timestamp.text = [dateFormatter stringFromDate:date];

    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellText = [[self.listData objectAtIndex:indexPath.row] valueForKey:@"content"];
    UIFont *cellFont = [UIFont systemFontOfSize:12];
    CGSize constraintSize = CGSizeMake(262.0, CGFLOAT_MAX); // content width from xib = 267.
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];

    // Full cell height of 77 - default content height of 36 = 41. + a little bit of bottom padding.
    return fmax(77.0, labelSize.height + 45);
}

- (void) adjustRequestBackoff
{
    if (self.backoff > 4) {
        return;
    }

    if (self.backoff == 0) {
        self.backoff = .8;
    } else if (self.backoff < 10) {
        self.backoff *= 2;
    } else {
        self.backoff = 10;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                          initWithNibName:@"ComposeViewController"
                                          bundle:nil];

    NSDictionary *dict = [listData objectAtIndex:indexPath.row];
    composeView.type = [dict objectForKey:@"type"];
    [[self navigationController] pushViewController:composeView animated:YES];

    if ([[dict objectForKey:@"type"] isEqualToString:@"stream"]) {
        composeView.recipient.text = [dict valueForKey:@"display_recipient"];
        [composeView.subject setHidden:NO];
        composeView.subject.text = [dict valueForKey:@"subject"];
    } else if ([[dict objectForKey:@"type"] isEqualToString:@"private"]) {
        [composeView.subject setHidden:YES];

        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (NSDictionary *recipient in recipients) {
            if (![[recipient valueForKey:@"email"] isEqualToString:self.delegate.email]) {
                [recipient_array addObject:[recipient valueForKey:@"email"]];
            }
        }
        composeView.privateRecipient.text = [recipient_array componentsJoinedByString:@", "];
    }

    [composeView release];
}

- (void) addMessages: (NSArray*) messages {
    if (!messages) {
        return;
    }

    BOOL backfill = FALSE;
    if ([self.listData count] == 0) {
        backfill = TRUE;
    }

    for (NSDictionary *message in messages) {
        [self.allMessages addObject:message];

        if ([[message objectForKey:@"type"] isEqualToString:@"stream"]) {
            NSString* stream = [message objectForKey:@"display_recipient"];
            if (![self streamInHome:stream]) {
                continue;
            }
        }

        NSArray *newIndexPaths = [NSArray arrayWithObjects:
                                  [NSIndexPath indexPathForRow:[self.listData count]
                                                     inSection:0], nil];
        [self.listData addObject: message];

        [self.tableView insertRowsAtIndexPaths:newIndexPaths
                              withRowAnimation:UITableViewRowAnimationTop];
        self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 200.0, 0.0);
    }
    
    if (backfill && [self.listData count]) {
        // If we are backfilling old messages, these are messages you've necessarily already
        // seen that are just being fetched as context, so scroll to the bottom of them.
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath
                                                indexPathForRow:[self.listData count] - 1
                                                inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:NO];
    }
}

- (void) getOldMessages: (NSDictionary *)args {
    long anchor = [[args objectForKey:@"anchor"] integerValue];
    if (!anchor) {
        anchor = self.pointer;
    }
    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       @"false", @"apply_markdown",
                                       [NSString stringWithFormat:@"%li", anchor], @"anchor",
                                       [NSString stringWithFormat:@"%i",
                                        [[args objectForKey:@"num_before"] integerValue]], @"num_before",
                                       [NSString stringWithFormat:@"%i",
                                        [[args objectForKey:@"num_after"] integerValue]], @"num_after",
                                       @"{}", @"narrow", nil];


    [[HumbugAPIClient sharedClient] getPath:@"messages" parameters:postFields success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        [self performSelectorOnMainThread:@selector(addMessages:)
                               withObject:[json objectForKey:@"messages"] waitUntilDone:YES];

        if ([[args objectForKey:@"scroll_to_pointer"] boolValue]) {
            [self scrollToPointer:self.pointer];
        }

        NSDictionary *lastMsg = (NSDictionary *)[self.listData lastObject];
        if (lastMsg) {
            int latest_msg_id = [[lastMsg objectForKey:@"id"] intValue];
            if (latest_msg_id < self.maxMessageId) {
                // There are still historical messages to fetch.
                NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"false", @"apply_markdown",
                                      [NSNumber numberWithInteger:latest_msg_id + 1], @"anchor",
                                      [NSNumber numberWithInteger:0], @"num_before",
                                      [NSNumber numberWithInteger:20], @"num_after",
                                      nil];
                [self getOldMessages:args];
            } else {
                self.backgrounded = FALSE;
                if (!self.pollingStarted) {
                    self.pollingStarted = TRUE;
                    [self startPoll];
                }
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to load old messages: %@", [error localizedDescription]);
    }];
}

- (BOOL) streamInHome:(NSString *)stream
{
    NSDictionary *streamInfo = [[self streams] objectForKey:stream];

    if (!streamInfo) {
        return YES;
    }

    return [[streamInfo objectForKey:@"in_home_view"] boolValue];
}

- (void) longPoll {
    while (([[NSDate date] timeIntervalSince1970] - self.lastRequestTime) < self.backoff) {
        [NSThread sleepForTimeInterval:.5];
    }

    self.lastRequestTime = [[NSDate date] timeIntervalSince1970];


    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       @"false", @"apply_markdown",
                                       queueId, @"queue_id",
                                       [NSString stringWithFormat:@"%i", self.lastEventId], @"last_event_id",
                                       nil];

    [[HumbugAPIClient sharedClient] getPath:@"events" parameters:postFields success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        if (self.waitingOnErrorRecovery == TRUE) {
            self.waitingOnErrorRecovery = FALSE;
            [self.delegate dismissErrorScreen];
        }
        self.backoff = 0;
        self.pollFailures = 0;

        NSMutableArray *messages = [[NSMutableArray alloc] init];
        for (NSDictionary *event in [json objectForKey:@"events"]) {
            NSString *eventType = [event objectForKey:@"type"];
            if ([eventType isEqualToString:@"message"]) {
                NSMutableDictionary *msg = [[event objectForKey:@"message"] mutableCopy];
                [msg setValue:[event objectForKey:@"flags"] forKey:@"flags"];
                [messages addObject:msg];
            } else if ([eventType isEqualToString:@"pointer"]) {
                long newPointer = [[event objectForKey:@"pointer"] longValue];

                if (newPointer > self.pointer) {
                    [self scrollToPointer:newPointer];
                }
            }

            self.lastEventId = MAX(self.lastEventId, [[event objectForKey:@"id"] intValue]);

        }

        // If we're not hidden/in the background, load the new messages immediately
        if (!self.backgrounded) {
            [self performSelectorOnMainThread:@selector(addMessages:)
                                   withObject:messages waitUntilDone:YES];
        }

        [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to do long poll: %@", [error localizedDescription]);

        if ([operation isKindOfClass:[AFJSONRequestOperation class]]) {
            NSDictionary *json = (NSDictionary *)[(AFJSONRequestOperation *)operation responseJSON];
            NSString *errorMsg = [json objectForKey:@"msg"];
            if ([[operation response] statusCode] == 400 &&
                ([errorMsg rangeOfString:@"too old"].location != NSNotFound ||
                 [errorMsg rangeOfString:@"Bad event queue id"].location != NSNotFound)) {
                // Reload our data if we've been GCed
                self.pollingStarted = NO;
                [self reset];
                return;
            }
        }

        self.pollFailures++;
        [self adjustRequestBackoff];
        if (self.pollFailures > 5 && self.waitingOnErrorRecovery == FALSE) {
            self.waitingOnErrorRecovery = TRUE;
            [self.delegate showErrorScreen:self.view
                              errorMessage:@"Error getting messages. Please try again in a few minutes."];
        }

        // Continue polling regardless
        [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    }];
}

- (void) startPoll {
    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

- (void) updatePointer {
    if ([self.listData count] == 0) {
        return;
    }
    NSIndexPath *indexPath = [self.tableView indexPathForCell:
                              [self.tableView.visibleCells objectAtIndex:0]];
    NSUInteger lastIndex = [indexPath indexAtPosition:[indexPath length] - 1];
    MessageCell *pointedCell = [self.listData objectAtIndex:lastIndex];

    long newPointer = [[pointedCell valueForKey:@"id"] longValue];
    if (newPointer <= self.pointer)
        return;

    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [[NSString alloc] initWithFormat:@"%ld", newPointer],
                                       @"pointer", nil];

    [[HumbugAPIClient sharedClient] putPath:@"users/me/pointer" parameters:postFields success:nil failure:nil];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self performSelectorInBackground:@selector(updatePointer) withObject: nil];
}

-(void)composeButtonPressed {
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                    initWithNibName:@"ComposeViewController"
                                    bundle:nil];
    composeView.type = @"stream";
    [[self navigationController] pushViewController:composeView animated:YES];
    [composeView release];
}

-(void)composePMButtonPressed {
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                     initWithNibName:@"ComposeViewController"
                                     bundle:nil];
    composeView.type = @"private";
    [[self navigationController] pushViewController:composeView animated:YES];
    [composeView release];
}

-(int) rowWithId: (int)messageId
{
    int i = 0;
    for (i = 0; i < [self.listData count]; i++) {
        if ([[self.listData[i] objectForKey:@"id"] intValue] == messageId) {
            return i;
        }
    }
    return FALSE;
}

-(void)repopulateList
{
    // If the pointer has moved because messages were consumed on another device, clear
    // the list and re-populate it.
    [self.listData removeAllObjects];
    [self.allMessages removeAllObjects];
    self.pointer = -1;
    self.maxMessageId = -1;
    self.lastEventId = -1;
    self.pollFailures = 0;
    self.queueId = @"";
    [self initialPopulate];
    [self.tableView reloadData];
}

-(void)scrollToPointer:(long)newPointer
{
    int pointerRowNum = [self rowWithId:newPointer];
    if (pointerRowNum) {
        // If the pointer is already in our table, but not visible, scroll to it
        // but don't try to clear and refetch messages.
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath
                                                indexPathForRow:pointerRowNum
                                                inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:NO];
    }
    self.pointer = newPointer;
}

-(void)reset {
    // Hide any error screens if visible
    [self.delegate dismissErrorScreen];

    // Fetch the pointer, then reset
    [[HumbugAPIClient sharedClient] getPath:@"users/me" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;
        int updatedPointer = [[json objectForKey:@"pointer"] intValue];

        if (updatedPointer != -1) {
            [self scrollToPointer:updatedPointer];
            self.backgrounded = FALSE;
        }

        [self repopulateList];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to fetch pointer: %@", [error localizedDescription]);
        [self repopulateList];
    }];
}

- (UIColor *)streamColor:(NSString *)withName {
    NSDictionary *stream = [[self streams] objectForKey:withName];
    if (stream == NULL) {
        NSLog(@"Error loading stream data to fetch color, %@", withName);
        return [StreamViewController defaultStreamColor];
    }
    NSString* colorHex = [stream objectForKey:@"color"];
    if (colorHex == NULL || [colorHex isEqualToString:@""]) {
        NSLog(@"Got no color for stream %@", withName);
        return [StreamViewController defaultStreamColor];
    }

    return [UIColor colorWithHexString:colorHex defaultColor:[StreamViewController defaultStreamColor]];
}

@end
