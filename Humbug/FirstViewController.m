#import "FirstViewController.h"
#import "HumbugAppDelegate.h"

@implementation FirstViewController
@synthesize listData;
@synthesize messageCell = _messageCell;
@synthesize first, last;
@synthesize gravatars;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.first = -1;
    self.last = -1;
    self.tableView.rowHeight = 77;
    self.listData = [[NSMutableArray alloc] init];
    self.gravatars = [[NSMutableDictionary alloc] init];
    
    [self startPoll];
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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Pale yellow, #FEFFE0
    MessageCell *my_cell = (MessageCell *)cell;
    if ([my_cell.subject.text isEqualToString:@""]) {
        // For non-stream messages, color cell background yellow.
        cell.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255 blue:224.0/255 alpha:1];
        my_cell.huddleDisplayRecipient.backgroundColor = [UIColor colorWithRed:51.0/255 green:51.0/255 blue:51.0/255 alpha:1];
        my_cell.huddleDisplayRecipient.textColor = [UIColor whiteColor];
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

    NSString *type = [dict objectForKey:@"type"];
    if ([type isEqualToString:@"stream"]) {
        cell.displayRecipient.text = [dict objectForKey:@"display_recipient"];
        cell.subject.text = [dict objectForKey:@"subject"];
        cell.huddleDisplayRecipient.text = @"";
    } else if ([type isEqualToString:@"huddle"]) {
        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableString *recipient_string = [[NSMutableString alloc] initWithString:@"You and "];
        for (NSDictionary *recipient in recipients) {
            [recipient_string appendFormat:@"%@, ", [recipient objectForKey:@"full_name"]];
        }
        cell.huddleDisplayRecipient.text = recipient_string;
        cell.displayRecipient.text = @"";
        cell.subject.text = @"";
    } else {
        cell.huddleDisplayRecipient.text = [@"You and " stringByAppendingString:
                                            [[dict objectForKey:@"display_recipient"] objectForKey:@"full_name"]];
        cell.displayRecipient.text = @"";
        cell.subject.text = @"";
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

- (void) dataReceived: (NSData*) pollingResponseData {
    NSError *e = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData: pollingResponseData
                                                             options: NSJSONReadingMutableContainers
                                                               error: &e];

    if (!jsonDict) {
        NSLog(@"Error parsing JSON: %@", e);
    } else {
        for(NSDictionary *item in [jsonDict objectForKey:@"messages"]) {
            [self.listData addObject: item];
            int message_id = (int)[item valueForKey:@"id"];
            if (message_id < self.first) {
                self.first = message_id;
            }
            if (message_id > self.last) {
                self.last = message_id;
            }
        }
        [self.tableView reloadData];
    }
}

- (void) longPoll {
    //create an autorelease pool for the thread
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    NSHTTPURLResponse* response = nil;
    
    HumbugAppDelegate *delegate = (HumbugAppDelegate *)[UIApplication sharedApplication].delegate;
    
    NSDictionary *postFields = [NSDictionary dictionaryWithObjectsAndKeys:delegate.email, @"email",
                                delegate.apiKey, @"api-key",
                                [NSString stringWithFormat:@"%i", self.first], @"first",
                                [NSString stringWithFormat:@"%i", self.last], @"last", nil];
    
    NSData *pollingResponseData = [delegate makePOST: &response resource_path:@"/api/v1/get_messages" postFields:postFields];

    [self performSelectorOnMainThread:@selector(dataReceived:)
                           withObject:pollingResponseData waitUntilDone:YES];
    
    [pool drain];
    
    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

- (void) startPoll {
    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

@end
