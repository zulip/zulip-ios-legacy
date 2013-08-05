
//  ZulipAPIController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/24/13.
//
//

#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"
#import "ZulipAppDelegate.h"
#import "StreamViewController.h"
#import "RawMessage.h"
#import "UnreadManager.h"

#include "KeychainItemWrapper.h"

// Models
#import "ZSubscription.h"
#include "ZUser.h"

// AFNetworking
#import "AFJSONRequestOperation.h"

// Categories
#import "UIColor+HexColor.h"

// Private category to let us declare "private" member properties
@interface ZulipAPIController ()

@property (nonatomic, retain) NSString *apiKey;
@property (nonatomic, retain) NSString *clientID;
@property (nonatomic, retain) NSString *apiURL;

@property(nonatomic, retain) NSString *queueId;

@property(assign) int lastEventId;
@property(assign) int maxMessageId;
@property(assign) int pollFailures;

@property(assign) double backoff;
@property(assign) double lastRequestTime;

@property(nonatomic, assign) BOOL waitingOnErrorRecovery;
@property(nonatomic, assign) BOOL loadingInitialMessages;

@property(nonatomic, retain) ZulipAppDelegate *appDelegate;
@property(nonatomic, retain) AFHTTPRequestOperation *pollRequest;
@end

NSString * const kLongPollMessageNotification = @"LongPollMessages";
NSString * const kLongPollMessageData = @"LongPollMessageData";
NSString * const kInitialLoadFinished = @"InitialMessagesLoaded";


@implementation ZulipAPIController

// Explicitly synthesize so we _-prefix member vars,
// as we override the default getter/setters
@synthesize pointer = _pointer;
@synthesize backgrounded = _backgrounded;

- (id) init
{
    self = [super init];

    if (self) {
        [self clearSettings];
        self.appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
        _unreadManager = [[UnreadManager alloc] init];

        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]
                                             initWithIdentifier:@"ZulipLogin" accessGroup:nil];
        NSString *storedApiKey = [keychainItem objectForKey:(__bridge id)kSecValueData];
        NSString *storedEmail = [keychainItem objectForKey:(__bridge id)kSecAttrAccount];

        if (![storedApiKey isEqualToString:@""]) {
            // We have credentials, so try to reuse them. We may still have to log in if they are stale.
            self.apiKey = storedApiKey;
            self.email = storedEmail;

            [ZulipAPIClient setCredentials:self.email withAPIKey:self.apiKey];
            [self registerForQueue];
        }
    }

    return self;
}

- (void)clearSettings
{
    self.queueId = @"";
    self.apiKey = @"";
    self.clientID = @"";
    self.apiURL = @"";
    self.email = @"";
    self.fullName = @"";
    self.backgrounded = NO;
    self.waitingOnErrorRecovery = NO;
    self.loadingInitialMessages = YES;
    self.pointer = -1;
    self.lastEventId = -1;
    self.maxMessageId = -1;
    self.backoff = 0;
    self.pollFailures = 0;
    self.pollRequest = nil;
}

- (void)loadUserSettings
{
    // Load initial activity status, etc
}

- (void) login:(NSString *)username password:(NSString *)password result:(void (^) (bool success))result;
{
    NSDictionary *postFields =  @{@"username": username,
                                  @"password": password};

    NSLog(@"Trying to log in: %@", postFields);
    [[ZulipAPIClient sharedClient] postPath:@"fetch_api_key" parameters:postFields success:^(AFHTTPRequestOperation *operation , id responseObject) {
        NSDictionary *jsonDict = (NSDictionary *)responseObject;

        // If we were previously logged in, log out first
        if ([self loggedIn]) {
            [self logout];
        }

        self.apiKey = [jsonDict objectForKey:@"api_key"];
        self.email = username;

        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"ZulipLogin" accessGroup:nil];
        [keychainItem setObject:self.apiKey forKey:(__bridge id)kSecValueData];
        [keychainItem setObject:self.email forKey:(__bridge id)kSecAttrAccount];

        [ZulipAPIClient setCredentials:self.email withAPIKey:self.apiKey];
        [self registerForQueue];

        result(YES);
    } failure: ^( AFHTTPRequestOperation *operation , NSError *error ){
        NSLog(@"Failed to fetch_api_key %@", [error localizedDescription]);

        result(NO);
    }];
}

- (void) logout
{
    // Hide any error screens if visible
    [self.appDelegate dismissErrorScreen];

    [self clearSettings];
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]
                                         initWithIdentifier:@"ZulipLogin" accessGroup:nil];
    [keychainItem resetKeychainItem];
    [[ZulipAPIClient sharedClient] logout];

    [self.appDelegate reloadCoreData];
}

- (BOOL) loggedIn
{
    return ![self.apiKey isEqualToString:@""];
}

- (NSString *)domain
{
    NSString *host = [[[ZulipAPIClient sharedClient] baseURL] host];
    NSString *domainPart;
    if ([host isEqualToString:@"localhost"]) {
        domainPart = @"local";
    } else if ([host isEqualToString:@"staging.zulip.com"]) {
        domainPart = @"staging";
    } else {
        domainPart = [[self.email componentsSeparatedByString:@"@"] lastObject];
    }

    return [NSString stringWithFormat:@"%@-%@", self.email, domainPart];
}

- (void)reset
{
    [self clearSettings];
    [self registerForQueue];
}

- (void) registerForQueue
{
    // Register for events, then fetch messages
    [[ZulipAPIClient sharedClient] postPath:@"register" parameters:@{@"apply_markdown": @"false"}
    success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.pollFailures = 0;

        NSDictionary *json = (NSDictionary *)responseObject;

        self.queueId = [json objectForKey:@"queue_id"];
        self.lastEventId = [[json objectForKey:@"last_event_id"] intValue];
        self.maxMessageId = [[json objectForKey:@"max_message_id"] intValue];
        self.pointer = [[json objectForKey:@"pointer"] longValue];

        // Set the full name from realm_users
        // TODO save the whole list properly and use it for presence information
        NSArray *realm_users = [json objectForKey:@"realm_users"];
        for (NSDictionary *person in realm_users) {
            if ([[person objectForKey:@"email"] isEqualToString:self.email])
                self.fullName = [person objectForKey:@"full_name"];
        }

        NSLog(@"Registered for queue, pointer is %li", self.pointer);
        NSArray *subscriptions = [json objectForKey:@"subscriptions"];
        [self loadSubscriptionData:subscriptions];

        // Set up the home view
        [self.homeViewController initialPopulate];

        // Start long polling
        [self startPoll];

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failure doing registerForQueue...retrying %@", [error localizedDescription]);

        if (self.pollFailures > 5) {
            [self.appDelegate showErrorScreen:@"Unable to connect to Zulip."];

        }
        self.pollFailures++;
        [self performSelector:@selector(registerForQueue) withObject:self afterDelay:2];
    }];
}

- (ZSubscription *) subscriptionForName:(NSString *)name
{
    // TODO cache these in-memory
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    req.predicate = [NSPredicate predicateWithFormat:@"name = %@", name];

    NSError *error = NULL;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:req error:&error];
    if (error) {
        NSLog(@"Failed to fetch sub for name: %@, %@", name, [error localizedDescription]);
        return nil;
    } else if ([results count] > 1) {
        NSLog(@"WTF, got more than one subscription with the same name?! %@", results);
    } else if ([results count] == 0) {
        return nil;
    }

    return [results objectAtIndex:0];
}

- (long)pointer
{
    return _pointer;
}

- (void)setPointer:(long)pointer
{
    if (pointer <= _pointer)
        return;

    _pointer = pointer;
    NSDictionary *postFields = @{@"pointer": @(_pointer)};

    [[ZulipAPIClient sharedClient] putPath:@"users/me/pointer" parameters:postFields success:nil failure:nil];
}

- (BOOL)backgrounded
{
    return _backgrounded;
}

- (void)setBackgrounded:(BOOL)backgrounded
{
    if (_backgrounded == backgrounded)
        return;

    // Re-start polling
    if (_backgrounded && !backgrounded) {
        NSLog(@"Coming to the foreground!!");
        [self startPoll];
    }
    _backgrounded = backgrounded;
}

#pragma mark - Loading messages

- (void) loadMessagesAroundAnchor:(int)anchor
                           before:(int)before
                            after:(int)after
                    withOperators:(NarrowOperators *)operators
                             opts:(NSDictionary *)opts
                  completionBlock:(MessagesDelivered)block
{
    // Try to load the desired messages, either from the cache or from the API
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZMessage"];
    BOOL ascending;

    NSPredicate *predicate;
    if (before > 0) {
        fetchRequest.fetchLimit = before;
        ascending = NO;

        predicate = [NSPredicate predicateWithFormat:@"messageID <= %@", @(anchor)];
    } else {
        fetchRequest.fetchLimit = after;
        ascending = YES;

        predicate = [NSPredicate predicateWithFormat:@"messageID >= %@", @(anchor)];
    }
    NSMutableArray *predicates = [NSMutableArray arrayWithObject:predicate];
    if (operators != nil) {
        [predicates addObject:[operators allocAsPredicate]];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    }

    fetchRequest.predicate = predicate;

    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"messageID" ascending:ascending]];

    NSError *error = nil;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:fetchRequest error:&error];

    if (ascending == NO) {
        results = [[results reverseObjectEnumerator] allObjects];
    }

    int messagesLeft = 0;
    if (error) {
        NSLog(@"Error fetching results from Core Data for message request! %@ %@", [error localizedDescription], [error userInfo]);
    } else {
        // If we got enough messages, return them directly from local cache
        if ([results count] >= fetchRequest.fetchLimit) {
            block([self rawMessagesFromManaged:results]);

            if ([opts valueForKey:@"fetch_until_latest"]) {
                ZMessage *last = [results lastObject];
                [self fetchNewestMessages:block withNewestID:[last.messageID longValue]];
            }
            return;
        } else {
            messagesLeft = fetchRequest.fetchLimit - [results count];
        }

        // Send what we already fetched, then do an API query
        if ([results count] > 0) {
            block([self rawMessagesFromManaged:results]);
        }
    }

    // Fetch what's left
    if (before > 0) {
        before = messagesLeft;
    } else {
        after = messagesLeft;
    }

    NSMutableDictionary *args = [[NSMutableDictionary alloc] initWithDictionary:@{@"anchor": @(anchor),
                                                                                  @"num_before": @(before),
                                                                                  @"num_after": @(after)}];
    if (opts) {
        for (NSString *key in opts) {
            [args setObject:[opts objectForKey:key] forKey:key];
        }
    }

    [self getOldMessages:args narrow:operators completionBlock:block];
}

#pragma mark - Zulip API calls

/**
 Load messages from the Zulip API into Core Data
 */
- (void) getOldMessages: (NSDictionary *)args narrow:(NarrowOperators *)narrow completionBlock:(MessagesDelivered)block
{
    long anchor = [[args objectForKey:@"anchor"] integerValue];
    if (!anchor) {
        anchor = self.pointer;
    }

    NSString *narrowParam = @"{}";
    if (narrow)
        narrowParam = [narrow allocAsJSONPayload];

    NSDictionary *fields = @{@"apply_markdown": @"false",
                             @"anchor": @(anchor),
                             @"num_before": @([[args objectForKey:@"num_before"] intValue]),
                             @"num_after": @([[args objectForKey:@"num_after"] intValue]),
                             @"narrow": narrowParam
                             };

    NSLog(@"Getting message: %@", fields);

    [[ZulipAPIClient sharedClient] getPath:@"messages" parameters:fields success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        [self insertMessages:[json objectForKey:@"messages"] saveToCoreData:[narrow isHomeView] withCompletionBlock:block];

        if ([args valueForKey:@"fetch_until_latest"]) {
            NSDictionary *last = [[json objectForKey:@"messages"] lastObject];
            [self fetchNewestMessages:block withNewestID:[[last objectForKey:@"id"] longValue]];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to load old messages: %@", [error localizedDescription]);
    }];
}

- (void)fetchNewestMessages:(MessagesDelivered)block withNewestID:(long)newestID
{
    // If we have more messages to fetch to reach the newest message,
    // fetch them.
    // TODO we only support "All messages"
    if (newestID < self.maxMessageId) {
        // There are still historical messages to fetch.
        NSDictionary *args = @{@"anchor": @(newestID + 1),
                               @"num_before": @(0),
                               @"num_after": @(20),
                               @"fetch_until_latest": @(YES)};
        [self getOldMessages:args narrow:nil completionBlock:block];
    } else if (self.loadingInitialMessages) {
        self.loadingInitialMessages = NO;

        NSNotification *message = [NSNotification notificationWithName:kInitialLoadFinished object:self];
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter postNotification:message];
    }
}
- (void) startPoll {
    if (self.pollRequest && [self.pollRequest isExecuting]) {
        [self.pollRequest cancel];
        self.pollRequest = 0;
    }

    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}


- (void) longPoll {
    while (([[NSDate date] timeIntervalSince1970] - self.lastRequestTime) < self.backoff) {
        [NSThread sleepForTimeInterval:.5];
    }

    self.lastRequestTime = [[NSDate date] timeIntervalSince1970];

    NSDictionary *fields = @{@"apply_markdown": @"false",
                             @"queue_id": self.queueId,
                             @"last_event_id": @(self.lastEventId)};

    NSMutableURLRequest *request = [[ZulipAPIClient sharedClient] requestWithMethod:@"GET" path:@"events" parameters:fields];
    [request setTimeoutInterval:120];

    self.pollRequest = [[ZulipAPIClient sharedClient] HTTPRequestOperationWithRequest:request
                                                                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        if (self.waitingOnErrorRecovery == YES) {
            self.waitingOnErrorRecovery = NO;
            [self.appDelegate dismissErrorScreen];
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

                self.pointer = newPointer;
            }

            self.lastEventId = MAX(self.lastEventId, [[event objectForKey:@"id"] intValue]);
        }

        // If we're not hidden/in the background, load the new messages immediately
        if (!self.backgrounded) {
            // TODO figure out why the dispatch_async body is never executed
//            dispatch_async(dispatch_get_main_queue(), ^{
                [self insertMessages:messages saveToCoreData:YES withCompletionBlock:^(NSArray *finishedMessages) {
                    NSNotification *longPollMessages = [NSNotification notificationWithName:kLongPollMessageNotification
                                                                                     object:self
                                                                                   userInfo:@{kLongPollMessageData: finishedMessages}];
                    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                    [notificationCenter postNotification:longPollMessages];
                }];
//            });
        }

        [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to do long poll: %@", [error localizedDescription]);

        BOOL ignoreError = NO;

        // TODO
        // Ignore 504 errors from nginx, until I can figure out what they are
        if ([[operation response] statusCode] == 504) {
            ignoreError = YES;
        }

        if ([operation isKindOfClass:[AFJSONRequestOperation class]]) {
            NSDictionary *json = (NSDictionary *)[(AFJSONRequestOperation *)operation responseJSON];
            NSString *errorMsg = [json objectForKey:@"msg"];
            if ([[operation response] statusCode] == 400 &&
                ([errorMsg rangeOfString:@"too old"].location != NSNotFound ||
                 [errorMsg rangeOfString:@"Bad event queue id"].location != NSNotFound)) {
                    // Reset if we've been GCed, we need a new event queue and all that
                    [self reset];
                    return;
                }
        }

        if (!ignoreError) {
            self.pollFailures++;
            [self adjustRequestBackoff];
            if (self.pollFailures > 5 && self.waitingOnErrorRecovery == NO) {
                self.waitingOnErrorRecovery = YES;
                [self.appDelegate showErrorScreen:@"Error getting messages. Please try again in a few minutes."];
            }
        }

        // Continue polling regardless
        [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    }];

    [[ZulipAPIClient sharedClient] enqueueHTTPRequestOperation:self.pollRequest];
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

#pragma mark - Core Data Insertion

- (void) loadSubscriptionData:(NSArray *)subscriptions
{
    // Loads subscriptions from the server into Core Data
    // First, get all locally known-about subs. We'll then update those, delete old, and add new ones

    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    NSError *error = NULL;
    NSArray *subs = [[self.appDelegate managedObjectContext] executeFetchRequest:req error:&error];
    if (error) {
        NSLog(@"Failed to load subscriptions from database: %@", [error localizedDescription]);
        return;
    }

    NSMutableDictionary *oldSubsDict = [[NSMutableDictionary alloc] init];
    for (ZSubscription *sub in subs) {
        [oldSubsDict setObject:sub forKey:sub.name];
    }

    NSMutableSet *subNames = [[NSMutableSet alloc] init];
    for (NSDictionary *newSub in subscriptions) {
        NSString *subName = [newSub objectForKey:@"name"];
        ZSubscription *sub;

        [subNames addObject:subName];
        if ([oldSubsDict objectForKey:subName]) {
            // We already have the sub, lets just update it to conform
            sub = [oldSubsDict objectForKey:subName];
        } else {
            // New subscription
            sub = [NSEntityDescription insertNewObjectForEntityForName:@"ZSubscription" inManagedObjectContext:[self.appDelegate managedObjectContext]];
            sub.name = subName;
        }
        // Set settings from server
        sub.color = [newSub objectForKey:@"color"];
        sub.in_home_view = [NSNumber numberWithBool:[[newSub objectForKey:@"in_home_view"] boolValue]];
        sub.invite_only = [NSNumber numberWithBool:[[newSub objectForKey:@"invite_only"] boolValue]];
        sub.notifications = [NSNumber numberWithBool:[[newSub objectForKey:@"notifications"] boolValue]];
    }
    // Remove any subs that no longer exist
    NSSet *removed = [oldSubsDict keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ![subNames containsObject:key];
    }];

    for (NSString *subName in removed) {
        [[self.appDelegate managedObjectContext] deleteObject:[oldSubsDict objectForKey:@"subName"]];
    }

    error = NULL;
    [[self.appDelegate managedObjectContext] save:&error];
    if (error) {
        NSLog(@"Failed to save subscription updates: %@", [error localizedDescription]);
    }
}

- (void)insertMessages:(NSArray *)messages saveToCoreData:(BOOL)saveToCD withCompletionBlock:(MessagesDelivered)block
{
    // Build our returned RawMessages
    // Then, if we are saving to Core Data,
    // do the CD save steps
    NSMutableArray *rawMessages = [[NSMutableArray alloc] init];
    NSMutableDictionary *rawMessagesDict = [[NSMutableDictionary alloc] init];
    for(NSDictionary *json in messages) {
        RawMessage *msg = [self rawMessageFromJSON:json];
        [rawMessages addObject:msg];
        [rawMessagesDict setObject:msg forKey:msg.messageID];
    }

    // Pass the downloaded messages back to whichever message list asked for it
    block(rawMessages);

    if (!saveToCD) {
        return;
    }

    // Do the core data inserting asynchronously
    // TODO figure out why body of dispatch_async is not being called
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        code
        // Insert/Update messages into Core Data.
        // First we fetch existing messages to update
        // Then we update/create any missing ones

        // Extract message IDs to insert
        // NOTE: messages MUST be already sorted in ascending order!
        NSArray *ids = [messages valueForKey:@"id"];

        // Extract messages that already exist, sorted ascending
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZMessage"];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(messageID IN %@)", ids];
        fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"messageID" ascending:YES]];
        NSError *error = nil;
        NSArray *existing = [[self.appDelegate managedObjectContext] executeFetchRequest:fetchRequest error:&error];
        if (error) {
            NSLog(@"Error fetching existing messages in insertMessages: %@ %@", [error localizedDescription], [error userInfo]);
            return;
        }

        // Now we have a list of (sorted) new IDs and existing ZMessages. Walk through them in order and insert/update
        NSUInteger newMsgIdx = 0, existingMsgIdx = 0;

        NSMutableArray *zmessages = [[NSMutableArray alloc] init];
        while (newMsgIdx < [ids count]) {
            int msgId = [[ids objectAtIndex:newMsgIdx] intValue];
            RawMessage *rawMsg = [rawMessagesDict objectForKey:@(msgId)];

            ZMessage *msg = nil;
            if (existingMsgIdx < [existing count])
                msg = [existing objectAtIndex:existingMsgIdx];

            // If we got a matching ZMessage for this ID, we want to update
            if (msg && msgId == [msg.messageID intValue]) {
                newMsgIdx++;
                existingMsgIdx++;
            } else {
                // Otherwise this message is NOT in Core Data, so insert and move to the next new message
                msg = [NSEntityDescription insertNewObjectForEntityForName:@"ZMessage" inManagedObjectContext:[self.appDelegate managedObjectContext]];
                msg.messageID = @(msgId);

                newMsgIdx++;
            }

            msg.content = rawMsg.content;
            msg.avatar_url = rawMsg.avatar_url;
            msg.subject = rawMsg.subject;
            msg.type = rawMsg.type;
            msg.timestamp = rawMsg.timestamp;
            msg.pm_recipients = rawMsg.pm_recipients;
            msg.sender = rawMsg.sender;
            msg.stream_recipient = rawMsg.stream_recipient;
            msg.subscription = rawMsg.subscription;
            [msg setMessageFlags:rawMsg.messageFlags];

            [zmessages addObject:msg];
        }

        error = nil;
        [[self.appDelegate managedObjectContext] save:&error];
        if (error) {
            NSLog(@"Error saving new messages: %@ %@", [error localizedDescription], [error userInfo]);
        }

//    });
}


- (RawMessage *)rawMessageFromJSON:(NSDictionary *)msgDict
{
    RawMessage *msg = [[RawMessage alloc] init];

    NSArray *stringProperties = @[@"content", @"avatar_url", @"subject", @"type"];
    for (NSString *prop in stringProperties) {
        // Use KVC to set the property value by the string name
        [msg setValue:[msgDict valueForKey:prop] forKey:prop];
    }
    msg.timestamp = [NSDate dateWithTimeIntervalSince1970:[[msgDict objectForKey:@"timestamp"] intValue]];
    msg.messageID = [NSNumber numberWithInteger:[[msgDict objectForKey:@"id"] integerValue]];

    [msg setMessageFlags:[msgDict objectForKey:@"flags"]];

    if ([msg.type isEqualToString:@"stream"]) {
        msg.stream_recipient = [msgDict valueForKey:@"display_recipient"];
        msg.subscription = [self subscriptionForName:msg.stream_recipient];
    } else {
        msg.stream_recipient = @"";

        NSArray *involved_people = [msgDict objectForKey:@"display_recipient"];
        for (NSDictionary *person in involved_people) {
            ZUser *recipient  = [self addPerson:person andSave:YES];

            if (recipient) {
                [[msg pm_recipients] addObject:recipient];
            }
        }
    }

    if ([msgDict objectForKey:@"sender_id"]) {
        NSDictionary *senderDict = @{@"full_name": [msgDict objectForKey:@"sender_full_name"],
                                     @"email": [msgDict objectForKey:@"sender_email"],
                                     @"id": [msgDict objectForKey:@"sender_id"],
                                     @"avatar_url": [msgDict objectForKey:@"avatar_url"]};
        ZUser *sender = [self addPerson:senderDict andSave:NO];
        msg.sender = sender;
    }

    [self.unreadManager handleIncomingMessage:msg];
    return msg;
}

- (ZUser *)addPerson:(NSDictionary *)personDict andSave:(BOOL)save
{
    int userID = [[personDict objectForKey:@"id"] intValue];

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ZUser"];
    request.predicate = [NSPredicate predicateWithFormat:@"userID == %i", userID];

    NSError *error = nil;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error fetching ZUser: %@ %@", [error localizedDescription], [error userInfo]);

        return nil;
    }

    ZUser *user = nil;
    if ([results count] != 0) {
        user = (ZUser *)[results objectAtIndex:0];
    } else {
        if (![personDict objectForKey:@"id"]) {
            NSLog(@"Tried to add a new person without an ID?! %@", personDict);
            return nil;
        }

        user = [NSEntityDescription insertNewObjectForEntityForName:@"ZUser" inManagedObjectContext:[self.appDelegate managedObjectContext]];
        user.userID = @(userID);
    }
    NSArray *stringProperties = @[@"email", @"avatar_url", @"full_name"];
    for (NSString *prop in stringProperties) {
        // Use KVC to set the property value by the string name
        [user setValue:[personDict valueForKey:prop] forKey:prop];
    }

    if (save) {
        error = nil;
        [[self.appDelegate managedObjectContext] save:&error];
        if (error) {
            NSLog(@"Error saving ZUser: %@ %@", [error localizedDescription], [error userInfo]);

            return nil;
        }
    }

    return user;
}

- (NSArray *)rawMessagesFromManaged:(NSArray *)messages
{
    NSMutableArray *rawMessages = [[NSMutableArray alloc] init];
    for (ZMessage *msg in messages) {
        RawMessage *raw = [RawMessage allocFromZMessage:msg];
        [rawMessages addObject:raw];
        [self.unreadManager handleIncomingMessage:raw];
    }
    return rawMessages;
}

#pragma mark - Core Data Getters

- (UIColor *)streamColor:(NSString *)name withDefault:(UIColor *)defaultColor {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    request.predicate = [NSPredicate predicateWithFormat:@"name = %@", name];


    NSError *error = nil;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error fetching subscription to get color: %@, %@", [error localizedDescription], [error userInfo]);
        return defaultColor;
    } else if ([results count] == 0) {
        NSLog(@"Error loading stream data to fetch color, %@", name);
        return defaultColor;
    }

    ZSubscription *sub = [results objectAtIndex:0];
    return [UIColor colorWithHexString:sub.color defaultColor:defaultColor];
}

// Singleton
+ (ZulipAPIController *)sharedInstance {
    static ZulipAPIController *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[ZulipAPIController alloc] init];
    });

    return _sharedClient;
}


@end
