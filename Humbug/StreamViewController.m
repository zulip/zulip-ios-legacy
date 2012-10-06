#import "FirstViewController.h"
#import "HumbugAppDelegate.h"

@implementation StreamViewController
@synthesize listData;
@synthesize messageCell = _messageCell;
@synthesize first, last;
@synthesize gravatars;
@synthesize delegate;

- (id)initWithStyle:(UITableViewStyle)style
{
    return [super initWithStyle:style];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.first = -1;
    self.last = -1;
    self.listData = [[NSMutableArray alloc] init];
    self.gravatars = [[NSMutableDictionary alloc] init];
    self.delegate = (HumbugAppDelegate *)[UIApplication sharedApplication].delegate;

    dispatch_queue_t downloadQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(downloadQueue, ^{

        if ([self fetchPointer] != TRUE) {
            [self.delegate showErrorScreen:self.view
                              errorMessage:@"Unable to fetch messages. Please try again in a few minutes."];
        }
        [self getOldMessages];
    });
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

- (UIImage *)getGravatar:(NSString *)gravatarHash
{
    UIImage *gravatar = [self.gravatars objectForKey:gravatarHash];
    if (gravatar != nil) {
        return gravatar;
    }

    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:
                                                       [NSString stringWithFormat:
                                                        @"https://secure.gravatar.com/avatar/%@?d=identicon&s=30",
                                                        gravatarHash]]];
    gravatar = [UIImage imageWithData:imageData];
    [self.gravatars setObject:gravatar forKey:gravatarHash];

    return gravatar;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    MessageCell *my_cell = (MessageCell *)cell;
    if ([my_cell.type isEqualToString:@"stream"]) {
        my_cell.header.backgroundColor = [UIColor colorWithRed:187.0/255
                                                         green:187.0/255
                                                          blue:187.0/255
                                                         alpha:1];
    } else {
        // For non-stream messages, color cell background pale yellow (#FEFFE0).
        cell.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255
                                                blue:224.0/255 alpha:1];
        my_cell.header.backgroundColor = [UIColor colorWithRed:51.0/255
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
    if ([cell.type isEqualToString:@"stream"]) {
        cell.header.text = [NSString stringWithFormat:@"%@ | %@",
                            [dict objectForKey:@"display_recipient"],
                            [dict objectForKey:@"subject"]];
    } else if ([cell.type isEqualToString:@"huddle"]) {
        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (NSDictionary *recipient in recipients) {
            if (![[recipient valueForKey:@"email"] isEqualToString:self.delegate.email]) {
                [recipient_array addObject:[recipient objectForKey:@"full_name"]];
            }
        }
        cell.header.text = [@"You and " stringByAppendingString:[recipient_array componentsJoinedByString:@", "]];
    } else {
        cell.header.text = [@"You and " stringByAppendingString:
                            [dict objectForKey:@"sender_full_name"]];
    }

    cell.sender.text = [dict objectForKey:@"sender_full_name"];
    cell.content.text = [dict objectForKey:@"content"];
    // Allow multi-line content.
    cell.content.lineBreakMode = UILineBreakModeWordWrap;
    cell.content.numberOfLines = 0;

    cell.gravatar.image = [self getGravatar:[dict objectForKey:@"gravatar_hash"]];

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
    CGSize constraintSize = CGSizeMake(267.0, CGFLOAT_MAX); // Cell width from xib = 267.
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];

    // Full cell height of 77 - default content width of 36 = 41. + a little bit of bottom padding.
    return fmax(77.0, labelSize.height + 45);
}

- (void) dataReceived: (NSData*) pollingResponseData {
    if (!pollingResponseData) {
        return;
    }
    NSError *e = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData: pollingResponseData
                                                             options: NSJSONReadingMutableContainers
                                                               error: &e];
    if (!jsonDict) {
        NSLog(@"Error parsing JSON: %@", e);
    } else {
        for(NSDictionary *item in [jsonDict objectForKey:@"messages"]) {
            int message_id = [[item objectForKey:@"id"] intValue];

            // We've already processed these. The API is inconsistent about bounds
            // and should be fixed so we don't have to do these checks.
            if ((message_id <= self.first) || (message_id == self.last)) {
                continue;
            }
            NSArray *newIndexPaths = [NSArray arrayWithObjects:
                                      [NSIndexPath indexPathForRow:[self.listData count]
                                                         inSection:0], nil];
            [self.listData addObject: item];

            [self.tableView insertRowsAtIndexPaths:newIndexPaths
                                  withRowAnimation:UITableViewRowAnimationTop];
            self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 200.0, 0.0);

            if (message_id < self.first) {
                self.first = message_id;
            }
            if (message_id > self.last) {
                self.last = message_id;
            }
        }
    }
}

- (void) getOldMessages {
    NSHTTPURLResponse* response = nil;
    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       self.delegate.email, @"email",
                                       self.delegate.apiKey, @"api-key",
                                       [NSString stringWithFormat:@"%i", self.last], @"start",
                                       @"newer", @"which",
                                       [NSString stringWithFormat:@"%i", 6], @"number", nil];

    NSData *pollingResponseData = [self.delegate makePOST:&response
                                            resource_path:@"get_old_messages"
                                               postFields:postFields
                                        useAPICredentials:TRUE];

    int old_last = self.last;
    [self performSelectorOnMainThread:@selector(dataReceived:)
                           withObject:pollingResponseData waitUntilDone:YES];

    if (self.last != old_last) {
        // There are still historical messages to fetch.
        [self performSelectorInBackground:@selector(getOldMessages) withObject: nil];
    } else {
        [self startPoll];
    }
}

- (void) longPoll {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NSHTTPURLResponse* response = nil;
    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [NSString stringWithFormat:@"%i", self.first], @"first",
                                       [NSString stringWithFormat:@"%i", self.last], @"last",
                                       nil];

    NSData *pollingResponseData = [self.delegate makePOST:&response
                                            resource_path:@"get_messages"
                                               postFields:postFields
                                        useAPICredentials:TRUE];

    [self performSelectorOnMainThread:@selector(dataReceived:)
                           withObject:pollingResponseData waitUntilDone:YES];

    [pool drain];

    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

- (void) startPoll {
    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self.tableView visibleCells];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:
                              [self.tableView.visibleCells objectAtIndex:0]];
    NSUInteger lastIndex = [indexPath indexAtPosition:[indexPath length] - 1];
    MessageCell *pointedCell = [self.listData objectAtIndex:lastIndex];
    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [pointedCell valueForKey:@"id"], @"pointer", nil];
    NSHTTPURLResponse* response = nil;

    [self.delegate makePOST:&response resource_path:@"update_pointer" postFields:postFields
          useAPICredentials:TRUE];
}

- (BOOL) fetchPointer {
    NSHTTPURLResponse *response;
    NSData *pointerData;

    NSMutableDictionary *postFields = [NSMutableDictionary dictionary];
    pointerData = [self.delegate makePOST:&response resource_path:@"get_profile"
                          postFields:postFields useAPICredentials:TRUE];

    if ([response statusCode] != 200) {
        NSLog(@"Error fetching pointer: %d", [response statusCode]);
        return FALSE;
    }
    NSError *e = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData: pointerData
                                                             options: NSJSONReadingMutableContainers
                                                               error: &e];
    if (!jsonDict) {
        NSLog(@"Error parsing JSON: %@", e);
        return FALSE;
    } else {
        int pointer = [[jsonDict objectForKey:@"pointer"] intValue];
        // Add a few messages of context before the current message.
        self.first = pointer - 3;
        self.last = pointer - 3;

        self.delegate.clientID = [jsonDict objectForKey:@"client_id"];
    }
    return TRUE;
}

@end
