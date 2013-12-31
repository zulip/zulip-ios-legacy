#import "ComposeViewController.h"
#import "ZulipAppDelegate.h"
#import "ZulipAPIClient.h"
#import "ZulipAPIController.h"
#import "UserCell.h"

#import "UIImageView+AFNetworking.h"

#import <QuartzCore/QuartzCore.h>
#import <Crashlytics/Crashlytics.h>

@interface ComposeViewController ()

@property (nonatomic, retain) RawMessage *replyTo;
@property (nonatomic, strong) NSString *recipientString;
@property (nonatomic, weak) UITextField *currentAutocompleteField;

@end

@implementation ComposeViewController

#pragma mark Setup/Teardown methods

- (id)initWithReplyTo:(RawMessage *)message
{
    self = [super initWithNibName:@"ComposeViewController" bundle:nil];
    if (self) {
        self.replyTo = message;
        [self sharedInit];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self sharedInit];
    }
    return self;
}

- (void)sharedInit
{
    self.completionMatches = [[NSMutableArray alloc] init];
    self.fullNameLookupDict = [[ZulipAPIController sharedInstance] fullNameLookupDict];
    self.streamLookup = [[ZulipAPIController sharedInstance] streamLookup];
}

- (void)viewWillAppear:(BOOL)animated
{
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.content.layer.cornerRadius = 5;
    self.content.clipsToBounds = YES;
    [self.content.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.content.layer setBorderWidth:2.0];

    // On iOS 7, don't extend our content under the toolbar
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        self.edgesForExtendedLayout = UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
    }

    self.completionsTableView.hidden = YES;
    [self.completionsTableView reloadData];

    if ([self.type isEqualToString:@"stream"]) {
        self.subject.hidden = NO;

        self.recipient.hidden = NO;
        self.recipient.text = self.replyTo.stream_recipient;

        self.subject.text = self.replyTo.subject;

        self.privateRecipient.hidden = YES;
    } else if ([self.type isEqualToString:@"private"]) {
        self.subject.hidden = YES;

        self.recipient.hidden = YES;

        self.privateRecipient.hidden = NO;

        NSSet *recipients = self.replyTo.pm_recipients;
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (ZUser *recipient in recipients) {
            if (![recipient.email isEqualToString:[[ZulipAPIController sharedInstance] email]]) {
                [recipient_array addObject:recipient.email];
            }
        }
        self.privateRecipient.text = [recipient_array componentsJoinedByString:@", "];
    }


    self.delegate = (ZulipAppDelegate *)[UIApplication sharedApplication].delegate;

    self.entryFields = [[NSMutableArray alloc] init];
    NSInteger tag = 1;
    UIView *aView;
    while ((aView = [self.view viewWithTag:tag])) {
        if (aView && [[aView class] isSubclassOfClass:[UIResponder class]]) {
            [self.entryFields addObject:aView];
        }
        tag++;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Zulip methods

- (IBAction)send
{
    [self.content resignFirstResponder];

    NSMutableDictionary *postFields;
    if ([self.type isEqualToString:@"stream"]) {
        postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"stream", @"type", self.recipient.text, @"to",
                      self.subject.text, @"subject", self.content.text, @"content",
                      nil];
    } else if ([self.type isEqualToString:@"private"]) {
        NSArray* recipient_array = [self.privateRecipient.text componentsSeparatedByString: @","];

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipient_array options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"private", @"type", jsonString, @"to",
                      self.content.text, @"content", nil];
    } else {
        NSLog(@"Invalid message type");
    }

    [[ZulipAPIClient sharedClient] postPath:@"messages" parameters:postFields success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        CLS_LOG(@"Error posting message: %@", [error localizedDescription]);
    }];

    [self.delegate.navController popViewControllerAnimated:YES];
}

- (void)getUserCompletionResultsWithQuery:(NSString*)searchString
{
    static NSMutableOrderedSet *prefixEmailMatches;
    static NSMutableOrderedSet *prefixNameMatches;
    static NSMutableOrderedSet *nonPrefixMatches;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefixEmailMatches = [[NSMutableOrderedSet alloc] init];
        prefixNameMatches = [[NSMutableOrderedSet alloc] init];
        nonPrefixMatches = [[NSMutableOrderedSet alloc] init];
    });

    searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [prefixEmailMatches removeAllObjects];
    [prefixNameMatches removeAllObjects];
    [nonPrefixMatches removeAllObjects];
    [self.completionMatches removeAllObjects];
    // match by email
    for(NSString *candidate in [self.fullNameLookupDict allKeys])
    {
        NSUInteger index = [candidate rangeOfString:searchString options:NSCaseInsensitiveSearch].location;
        if (index == 0) {
            if ([[candidate lowercaseString] isEqualToString:[searchString lowercaseString]]) {
                // got exact match: hide the completions
                self.completionsTableView.hidden = YES;
                return;
            }
            [prefixEmailMatches addObject:candidate];
        } else if (index != NSNotFound) {
            [nonPrefixMatches addObject:candidate];
        }
    }
    // match by full name
    for(NSString *candidate in [self.fullNameLookupDict allKeys])
    {
        NSUInteger index = [self.fullNameLookupDict[candidate] rangeOfString:searchString options:NSCaseInsensitiveSearch].location;
        if (index == 0) {
            //cannot hide the completions table, because you cannot PM by full name.
            [prefixNameMatches addObject:candidate];
        } else if (index != NSNotFound) {
            [nonPrefixMatches addObject:candidate];
        }
    }

    [prefixEmailMatches removeObjectsInArray:[prefixNameMatches array]];


    // sorry Leo, I tried. This prioritizes by non-bots then bots in the categories of
    // prefix-matches (names first, then emails) and then non-prefix-matches
    for(NSString *result in prefixNameMatches)
    {
        if ([result rangeOfString:@"-bot@"].location == NSNotFound)
            [self.completionMatches addObject:result];
    }
    for(NSString *result in prefixNameMatches)
    {
        if ([result rangeOfString:@"-bot@"].location != NSNotFound)
            [self.completionMatches addObject:result];
    }
    for(NSString *result in prefixEmailMatches)
    {
        if ([result rangeOfString:@"-bot@"].location == NSNotFound)
            [self.completionMatches addObject:result];
    }
    for(NSString *result in prefixEmailMatches)
    {
        if ([result rangeOfString:@"-bot@"].location != NSNotFound)
            [self.completionMatches addObject:result];
    }
    for(NSString *result in nonPrefixMatches)
    {
        if ([result rangeOfString:@"-bot@"].location == NSNotFound)
            [self.completionMatches addObject:result];
    }
    for(NSString *result in nonPrefixMatches)
    {
        if ([result rangeOfString:@"-bot@"].location != NSNotFound)
            [self.completionMatches addObject:result];
    }

    if ([self.completionMatches count])
    {
        self.completionsTableView.hidden = NO;
        [self.completionsTableView reloadData];
    } else
    {
        self.completionsTableView.hidden = YES;
    }
}

- (void)getStreamCompletionResultsWithQuery:(NSString *)searchString {
    static NSMutableOrderedSet *prefixMatches;
    static NSMutableOrderedSet *nonPrefixMatches;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefixMatches = [[NSMutableOrderedSet alloc] init];
        nonPrefixMatches = [[NSMutableOrderedSet alloc] init];
    });

    searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [prefixMatches removeAllObjects];
    [nonPrefixMatches removeAllObjects];
    [self.completionMatches removeAllObjects];

    for(NSString *candidate in self.streamLookup)
    {
        NSUInteger index = [candidate rangeOfString:searchString options:NSCaseInsensitiveSearch].location;
        if (index == 0) {
            if ([[candidate lowercaseString] isEqualToString:[searchString lowercaseString]]) {
                // got exact match: hide the completions
                self.completionsTableView.hidden = YES;
                return;
            }
            [prefixMatches addObject:candidate];
        } else if (index != NSNotFound) {
            [nonPrefixMatches addObject:candidate];
        }
    }

    [prefixMatches addObjectsFromArray:[nonPrefixMatches array]];
    self.completionMatches = [[prefixMatches array] mutableCopy];
    if (self.completionMatches.count > 0)
    {
        self.completionsTableView.hidden = NO;
        [self.completionsTableView reloadData];
    } else {
        self.completionsTableView.hidden = YES;
    }
}

- (void)getTopicCompletionResultsWithQuery:(NSString *)searchString forStream:(NSString *)streamName {

    searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    streamName = [streamName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"name == %@", streamName];
    fetchRequest.fetchLimit = 1;

    NSError *error = nil;
    NSArray *results = [appDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error || results.count != 1) {
        // No stream found
        return;
    }

    ZSubscription *subscription = results[0];
    NSMutableSet *subjects = [[NSMutableSet alloc] init];
    for (ZMessage *message in subscription.messages) {
        [subjects addObject:message.subject];
    }

    static NSMutableOrderedSet *prefixMatches;
    static NSMutableOrderedSet *nonPrefixMatches;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefixMatches = [[NSMutableOrderedSet alloc] init];
        nonPrefixMatches = [[NSMutableOrderedSet alloc] init];
    });

    [prefixMatches removeAllObjects];
    [nonPrefixMatches removeAllObjects];
    [self.completionMatches removeAllObjects];

    for(NSString *candidate in subjects)
    {
        NSUInteger index = [candidate rangeOfString:searchString options:NSCaseInsensitiveSearch].location;
        if (index == 0) {
            if ([[candidate lowercaseString] isEqualToString:[searchString lowercaseString]]) {
                // got exact match: hide the completions
                self.completionsTableView.hidden = YES;
                return;
            }
            [prefixMatches addObject:candidate];
        } else if (index != NSNotFound) {
            [nonPrefixMatches addObject:candidate];
        }
    }

    [prefixMatches addObjectsFromArray:[nonPrefixMatches array]];
    self.completionMatches = [[prefixMatches array] mutableCopy];
    if (self.completionMatches.count > 0)
    {
        self.completionsTableView.hidden = NO;
        [self.completionsTableView reloadData];
    } else {
        self.completionsTableView.hidden = YES;
    }
}

+ (NSArray*)splitUpRecipientsInString:(NSString*)string
{
    // as in the web app, we assume email addresses don't have "," or ";" in them
    NSError *error=NULL;
    NSString* normalizedString = [[NSRegularExpression regularExpressionWithPattern:@"\\s*[,;]\\s*" options:0 error:&error] stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:@","];
    return [normalizedString componentsSeparatedByString:@","];
}

+ (NSString*)replaceLastItemInStringList:(NSString*)string withString:(NSString*)replacementString
{
    NSMutableArray* components = [NSMutableArray arrayWithArray:[self splitUpRecipientsInString:string]];
    [components removeLastObject];
    [components addObject:replacementString];

    return [components componentsJoinedByString:@", "];
}

// recipient/stream/topic textfields
#pragma mark UITextFieldDelegate methods

- (void) animateTextView: (UITextView *) textView up: (BOOL) up
{
    const int movementDistance = 140; // tweak as needed
    const float movementDuration = 0.3f; // tweak as needed

    int movement = (up ? -movementDistance : movementDistance);

    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    self.view.frame = CGRectOffset(self.view.frame, 0, movement);
    [UIView commitAnimations];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // take the first autocomplete suggestion and start composing the message content
    if (textField == self.privateRecipient && ![self.completionsTableView isHidden])
    {
        [self tableView:self.completionsTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        [self.content becomeFirstResponder];
        return NO;
    }

	// Find the next entry field
	for (UIView *view in self.entryFields) {
		if (view.tag == (textField.tag + 1)) {
			[view becomeFirstResponder];
			break;
		}
	}
	return NO;
}

// called whenever characters are typed (or deleted)
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    self.currentAutocompleteField = textField;

    if (textField == self.privateRecipient)
    {
        NSString *searchString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        searchString = [ComposeViewController splitUpRecipientsInString:searchString].lastObject;
        [self getUserCompletionResultsWithQuery:searchString];
    } else if (textField == self.recipient) {
        NSString *searchString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        [self getStreamCompletionResultsWithQuery:searchString];
    } else if (textField == self.subject) {
        NSString *searchString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        [self getTopicCompletionResultsWithQuery:searchString forStream:self.recipient.text];
    }
    return YES;
}

// compose box textview
#pragma mark UITextViewDelegate methods

// recipient completions tableview
#pragma mark UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger) section {
    return self.completionMatches.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *email = [self.completionMatches objectAtIndex:indexPath.row];

    UserCell * cell = [tableView dequeueReusableCellWithIdentifier:[UserCell reuseIdentifier]];
    if (cell == nil) {
        NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"UserCellView" owner:self options:nil];
        cell = (UserCell *)[objects objectAtIndex:0];
    }
    [cell setUserWithEmail:email];

    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55;
}

#pragma mark UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UserCell *selectedCell = (UserCell *)[tableView cellForRowAtIndexPath:indexPath];
    self.currentAutocompleteField.text =                                   [ComposeViewController replaceLastItemInStringList:
                                   self.privateRecipient.text withString:
                                   selectedCell.email];

    if (self.currentAutocompleteField == self.privateRecipient) {
        self.currentAutocompleteField.text = [NSString stringWithFormat:@"%@, ", self.currentAutocompleteField.text];
    }

    self.completionsTableView.hidden = YES;
}


@end
