//
//  ComposeAutocompleteView.m
//  Zulip
//
//  Created by Michael Walker on 1/21/14.
//
//

#import "ComposeAutocompleteView.h"
#import "AutocompleteResults.h"
#import "ZulipAPIController.h"
#import "ZulipAppDelegate.h"
#import "UserCell.h"

@interface ComposeAutocompleteView ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSDictionary *fullNameLookupDict;
@property (nonatomic, strong) NSSet *streamLookup;
@property (nonatomic, strong) NSArray *completionMatches;
@property (nonatomic, weak) UITextField *currentAutocompleteField;

@property (weak, nonatomic) UITextField *privateRecipient;
@property (weak, nonatomic) UITextField *recipient;
@property (weak, nonatomic) UITextField *subject;

@end

@implementation ComposeAutocompleteView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.completionMatches = [[NSMutableArray alloc] init];
        self.fullNameLookupDict = [[ZulipAPIController sharedInstance] fullNameLookupDict];
        self.streamLookup = [self fetchStreamNames];

        self.delegate = self;
        self.dataSource = self;

        self.hidden = YES;
    }
    return self;
}

- (void)registerTextField:(UITextField *)textField
                  forType:(ComposeAutocompleteType)type {
    textField.delegate = self;

    switch(type) {
        case ComposeAutocompleteTypeUser:
            self.privateRecipient = textField;
            break;
        case ComposeAutocompleteTypeStream:
            self.recipient = textField;
            break;
        case ComposeAutocompleteTypeTopic:
            self.subject = textField;
            break;
    }
}

- (void)resetRegisteredTextFields {
    self.subject = nil;
    self.recipient = nil;
    self.privateRecipient = nil;
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.privateRecipient) {
        [self.messageBody becomeFirstResponder];
        self.hidden = YES;
    } else if (textField == self.recipient) {
        [self.subject becomeFirstResponder];
        self.hidden = YES;
    } else if (textField == self.subject) {
        [self.messageBody becomeFirstResponder];
        self.hidden = YES;
    }
	return NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    self.currentAutocompleteField = textField;

    if (textField == self.privateRecipient) {
        NSString *searchString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        searchString = [self.class splitUpRecipientsInString:searchString].lastObject;
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

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UserCell *selectedCell = (UserCell *)[tableView cellForRowAtIndexPath:indexPath];

    if (self.currentAutocompleteField == self.privateRecipient) {
        self.currentAutocompleteField.text = [self.class replaceLastItemInStringList: self.privateRecipient.text
                                                                                     withString:selectedCell.email];

        self.currentAutocompleteField.text = [NSString stringWithFormat:@"%@, ", self.currentAutocompleteField.text];
    } else {
        self.currentAutocompleteField.text = selectedCell.email;
    }

    self.hidden = YES;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger) section {
    return self.completionMatches.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *email = [self.completionMatches objectAtIndex:indexPath.row];

    UserCell *cell = [tableView dequeueReusableCellWithIdentifier:[UserCell reuseIdentifier]];
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

#pragma mark - Methods that fetch autocomplete results
- (void)getUserCompletionResultsWithQuery:(NSString*)searchString
{
    searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // match by email
    AutocompleteResults *emailResults = [[AutocompleteResults alloc] initWithArray:self.fullNameLookupDict.allKeys query:searchString];
    if (emailResults.isExactMatch) {
        self.hidden = YES;
        return;
    }

    AutocompleteResults *nameResults = [[AutocompleteResults alloc] initWithDictionary:self.fullNameLookupDict query:searchString];

    NSMutableOrderedSet *prefixEmailMatches = [emailResults.prefixMatches mutableCopy];
    NSMutableOrderedSet *prefixNameMatches = [nameResults.prefixMatches mutableCopy];

    NSMutableOrderedSet *nonPrefixMatches = [emailResults.nonPrefixMatches mutableCopy];
    [nonPrefixMatches addObjectsFromArray:[nameResults.nonPrefixMatches array]];

    [prefixEmailMatches removeObjectsInArray:[prefixNameMatches array]];

    // sorry Leo, I tried. This prioritizes by non-bots then bots in the categories of
    // prefix-matches (names first, then emails) and then non-prefix-matches
    NSMutableArray *results = [[NSMutableArray alloc] init];
    for(NSString *result in prefixNameMatches)
    {
        if ([result rangeOfString:@"-bot@"].location == NSNotFound)
            [results addObject:result];
    }
    for(NSString *result in prefixNameMatches)
    {
        if ([result rangeOfString:@"-bot@"].location != NSNotFound)
            [results addObject:result];
    }
    for(NSString *result in prefixEmailMatches)
    {
        if ([result rangeOfString:@"-bot@"].location == NSNotFound)
            [results addObject:result];
    }
    for(NSString *result in prefixEmailMatches)
    {
        if ([result rangeOfString:@"-bot@"].location != NSNotFound)
            [results addObject:result];
    }
    for(NSString *result in nonPrefixMatches)
    {
        if ([result rangeOfString:@"-bot@"].location == NSNotFound)
            [results addObject:result];
    }
    for(NSString *result in nonPrefixMatches)
    {
        if ([result rangeOfString:@"-bot@"].location != NSNotFound)
            [results addObject:result];
    }

    self.completionMatches = [results copy];
    if (self.completionMatches.count > 0)
    {
        self.hidden = NO;
        [self reloadData];
    } else
    {
        self.hidden = YES;
    }
}

- (void)getStreamCompletionResultsWithQuery:(NSString *)searchString {
    searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    AutocompleteResults *results = [[AutocompleteResults alloc] initWithSet:self.streamLookup query:searchString];
    if (results.isExactMatch) {
        self.hidden = YES;
        return;
    }

    self.completionMatches = results.orderedResults;
    if (self.completionMatches.count > 0)
    {
        self.hidden = NO;
        [self reloadData];
    } else {
        self.hidden = YES;
    }
}

- (void)getTopicCompletionResultsWithQuery:(NSString *)searchString forStream:(NSString *)streamName {

    searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    streamName = [streamName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableSet *subjects = [[NSMutableSet alloc] init];
    for (RawMessage *message in self.messageDelegate.messages) {
        if ([message.stream_recipient isEqualToString:streamName]) {
            [subjects addObject:message.subject];
        }
    }

    AutocompleteResults *topicResults = [[AutocompleteResults alloc] initWithSet:subjects query:searchString];
    if (topicResults.isExactMatch) {
        self.hidden = YES;
        return;
    }

    self.completionMatches = topicResults.orderedResults;
    if (self.completionMatches.count > 0)
    {
        self.hidden = NO;
        [self reloadData];
    } else {
        self.hidden = YES;
    }
}

# pragma mark - Private
+ (NSArray*)splitUpRecipientsInString:(NSString*)string {
    // as in the web app, we assume email addresses don't have "," or ";" in them
    NSError *error=NULL;
    NSString* normalizedString = [[NSRegularExpression regularExpressionWithPattern:@"\\s*[,;]\\s*" options:0 error:&error] stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:@","];
    return [normalizedString componentsSeparatedByString:@","];
}

+ (NSString*)replaceLastItemInStringList:(NSString*)string withString:(NSString*)replacementString {
    NSMutableArray* components = [NSMutableArray arrayWithArray:[self splitUpRecipientsInString:string]];
    [components removeLastObject];
    [components addObject:replacementString];

    return [components componentsJoinedByString:@", "];
}

- (NSSet *)fetchStreamNames {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    NSError *error = NULL;
    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSArray *subs = [appDelegate.managedObjectContext executeFetchRequest:req error:&error];
    if (error) {
        NSLog(@"Failed to load subscriptions from database: %@", [error localizedDescription]);
        return [NSSet set];
    }

    NSMutableSet *streamNames = [[NSMutableSet alloc] init];
    for (ZSubscription *sub in subs) {
        [streamNames addObject:sub.name];
    }
    
    return [streamNames copy];
}

@end
