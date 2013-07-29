
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

@property(nonatomic, retain) ZulipAppDelegate *appDelegate;
@property(nonatomic, retain) AFHTTPRequestOperation *pollRequest;
@end

@implementation ZulipAPIController

// Explicitly synthesize so we _-prefix member vars,
// as we override the default getter/setters
@synthesize pointer = _pointer;
@synthesize backgrounded = _backgrounded;

- (id) init
{
    id ret = [super init];

    self.queueId = @"";
    self.apiKey = @"";
    self.clientID = @"";
    self.apiURL = @"";
    self.email = @"";
    self.backgrounded = NO;
    self.waitingOnErrorRecovery = NO;
    self.pointer = -1;
    self.lastEventId = -1;
    self.maxMessageId = -1;
    self.backoff = 0;
    self.pollFailures = 0;
    self.pollRequest = nil;

    self.appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];

    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]
                                         initWithIdentifier:@"ZulipLogin" accessGroup:nil];
    NSString *storedApiKey = [keychainItem objectForKey:(__bridge id)kSecValueData];
    NSString *storedEmail = [keychainItem objectForKey:(__bridge id)kSecAttrAccount];

    if ([storedApiKey isEqualToString:@""]) {
    } else {
        // We have credentials, so try to reuse them. We may still have to log in if they are stale.
        self.apiKey = storedApiKey;
        self.email = storedEmail;

        [ZulipAPIClient setCredentials:self.email withAPIKey:self.apiKey];
        [self registerForQueue];
    }

    
    return ret;
}

- (void) login:(NSString *)username password:(NSString *)password result:(void (^) (bool success))result;
{
    NSDictionary *postFields =  @{@"username": username,
                                         @"password": password};
    
    [[ZulipAPIClient sharedClient] postPath:@"fetch_api_key" parameters:postFields success:^(AFHTTPRequestOperation *operation , id responseObject) {
        NSDictionary *jsonDict = (NSDictionary *)responseObject;

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

- (BOOL) loggedIn
{
    return ![self.apiKey isEqualToString:@""];
}

- (NSString *)domain
{
    NSString *host = [[[ZulipAPIClient sharedClient] baseURL] host];
    if ([host isEqualToString:@"localhost"]) {
        return @"local";
    } else if ([host isEqualToString:@"staging.zulip.com"]) {
        return @"staging";
    } else {
        return [[self.email componentsSeparatedByString:@"@"] lastObject];
    }
}

- (void) registerForQueue
{
    // Register for events, then fetch messages
    [[ZulipAPIClient sharedClient] postPath:@"register" parameters:@{@"apply_markdown": @"false"}
    success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        self.queueId = [json objectForKey:@"queue_id"];
        self.lastEventId = [[json objectForKey:@"last_event_id"] intValue];
        self.maxMessageId = [[json objectForKey:@"max_message_id"] intValue];
        self.pointer = [[json objectForKey:@"pointer"] longValue];

        NSArray *subscriptions = [json objectForKey:@"subscriptions"];
        [self loadSubscriptionData:subscriptions];

        [self getOldMessages:@{@"anchor": @(self.pointer),
                               @"num_before": @(12),
                               @"num_after": @(0)}];

        // Set up the home view
        [self.homeViewController initialPopulate];

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failure doing registerForQueue...retrying %@", [error localizedDescription]);

        [self performSelector:@selector(registerForQueue) withObject:self afterDelay:1];
    }];
}

- (ZSubscription *) subscriptionForName:(NSString *)name
{
    // TODO make sure this is coming from in-memory cache and not SQLite call,
    // as this is called for every incoming message
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

    // Re-start polling
    if (_backgrounded && !backgrounded) {
        NSLog(@"Coming to the foreground!!");
        [self fetchNewMessages];
        [self startPoll];
    }
    _backgrounded = backgrounded;
}

- (void) loadMessagesAroundAnchor:(int)anchor before:(int)before after:(int)after
{
    NSDictionary *args = @{@"anchor": @(anchor),
                           @"num_before": @(before),
                           @"num_after": @(after)};
    [self getOldMessages:args];
}

#pragma mark - Zulip API calls

/**
 When resuming, make sure we haven't missed any messages since we left the foreground
 */
- (void) fetchNewMessages
{
    ZMessage *newest = [self newestMessage];
    if (!newest) {
        return;
    }

    [self getOldMessages:@{@"anchor": newest.messageID,
                           @"num_before": @(0),
                           @"num_after": @(20)}];
}

/**
 Load messages from the Zulip API into Core Data
 */
- (void) getOldMessages: (NSDictionary *)args {
    long anchor = [[args objectForKey:@"anchor"] integerValue];
    if (!anchor) {
        anchor = self.pointer;
    }

    NSDictionary *fields = @{@"apply_markdown": @"false",
                             @"anchor": @(anchor),
                             @"num_before": @([[args objectForKey:@"num_before"] intValue]),
                             @"num_after": @([[args objectForKey:@"num_after"] intValue]),
                             @"narrow": @"{}"
                             };

    NSLog(@"Getting message: %@", fields);

    [[ZulipAPIClient sharedClient] getPath:@"messages" parameters:fields success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        // Insert message into Core Data back on the main thread
        [self performSelectorOnMainThread:@selector(insertMessages:)
                               withObject:[json objectForKey:@"messages"]
                            waitUntilDone:YES];

        // If we have more messages to fetch to reach the newest message,
        // fetch them. Otherwise, begin the long polling
        ZMessage *last = [self newestMessage];
        if (last) {
            int latest_msg_id = [last.messageID intValue];
            if (latest_msg_id < self.maxMessageId) {
                // There are still historical messages to fetch.
                NSDictionary *args = @{@"anchor": @(latest_msg_id + 1),
                                       @"num_before": @(0),
                                       @"num_after": @(20)};
                [self getOldMessages:args];
            } else {
                self.backgrounded = NO;
                if (![self.pollRequest isExecuting]) {
                    [self startPoll];
                }
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to load old messages: %@", [error localizedDescription]);
    }];
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
            [self performSelectorOnMainThread:@selector(insertMessages:)
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
                    // Load any new data if we've been GCed
                    [self fetchNewMessages];
                    return;
                }
        }

        self.pollFailures++;
        [self adjustRequestBackoff];
        if (self.pollFailures > 5 && self.waitingOnErrorRecovery == NO) {
            self.waitingOnErrorRecovery = YES;
            //            [self.appDelegate showErrorScreen:self.view
            //                              errorMessage:@"Error getting messages. Please try again in a few minutes."];
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

- (void)insertMessages:(NSArray *)messages
{
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
    int newMsgIdx = 0, existingMsgIdx = 0;
    while (newMsgIdx < [ids count]) {
        int msgId = [[ids objectAtIndex:newMsgIdx] intValue];
        NSDictionary *msgDict = [messages objectAtIndex:newMsgIdx];

        ZMessage *msg = nil;
        if (existingMsgIdx < [existing count])
            msg = [existing objectAtIndex:existingMsgIdx];

        // If we got a matching ZMessage for this ID, we want to update
        if (msg && msgId == [msg.messageID intValue]) {
//            NSLog(@"Updating EXISTING message: %i", msgId);

            newMsgIdx++;
            existingMsgIdx++;
        } else {
            // Otherwise this message is NOT in Core Data, so insert and move to the next new message
//            NSLog(@"Inserting NEW MESSAGE: %i", msgId);
            msg = [NSEntityDescription insertNewObjectForEntityForName:@"ZMessage" inManagedObjectContext:[self.appDelegate managedObjectContext]];
            msg.messageID = @(msgId);

            newMsgIdx++;
        }

        NSArray *stringProperties = @[@"content", @"avatar_url", @"subject", @"type"];
        for (NSString *prop in stringProperties) {
            // Use KVC to set the property value by the string name
            [msg setValue:[msgDict valueForKey:prop] forKey:prop];
        }
        msg.timestamp = [NSDate dateWithTimeIntervalSince1970:[[msgDict objectForKey:@"timestamp"] intValue]];

        if ([msg.type isEqualToString:@"stream"]) {
            msg.stream_recipient = [msgDict valueForKey:@"display_recipient"];
            msg.subscription = [self subscriptionForName:msg.stream_recipient];
        } else {
            msg.stream_recipient = @"";

            NSArray *involved_people = [msgDict objectForKey:@"display_recipient"];
            for (NSDictionary *person in involved_people) {
                ZUser *recipient  = [self addPerson:person];

                if (recipient) {
                    [msg addPm_recipientsObject:recipient];
                }
            }
        }

        if ([msgDict objectForKey:@"sender_id"]) {
            NSDictionary *senderDict = @{@"full_name": [msgDict objectForKey:@"sender_full_name"],
                                         @"email": [msgDict objectForKey:@"sender_email"],
                                         @"id": [msgDict objectForKey:@"sender_id"],
                                         @"avatar_url": [msgDict objectForKey:@"avatar_url"]};
            ZUser *sender = [self addPerson:senderDict];
            msg.sender = sender;
        }
    }

    error = nil;
    [[self.appDelegate managedObjectContext] save:&error];
    if (error) {
        NSLog(@"Error saving new messages: %@ %@", [error localizedDescription], [error userInfo]);
    }
}

- (ZUser *)addPerson:(NSDictionary *)personDict
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
        user = [NSEntityDescription insertNewObjectForEntityForName:@"ZUser" inManagedObjectContext:[self.appDelegate managedObjectContext]];
        user.userID = @(userID);
    }
    NSArray *stringProperties = @[@"email", @"avatar_url", @"full_name"];
    for (NSString *prop in stringProperties) {
        // Use KVC to set the property value by the string name
        [user setValue:[personDict valueForKey:prop] forKey:prop];
    }

    error = nil;
    [[self.appDelegate managedObjectContext] save:&error];
    if (error) {
        NSLog(@"Error saving ZUser: %@ %@", [error localizedDescription], [error userInfo]);

        return nil;
    }

    return user;
}

#pragma mark - Core Data Getters
- (ZMessage *)newestMessage
{
    // Fetch the newest message
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZMessage"];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"messageID" ascending:NO]];
    fetchRequest.fetchLimit = 1;

    NSError *error = nil;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"Error fetching newest message: %@, %@", [error localizedDescription], [error userInfo]);
        return nil;
    } else if ([results count] < 1) {
        NSLog(@"No newest message yet");
        return nil;
    }

    return [results objectAtIndex:0];
}

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
