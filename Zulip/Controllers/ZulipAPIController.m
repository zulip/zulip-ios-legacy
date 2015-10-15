//  ZulipAPIController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/24/13.
//
//

#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"
#import "ZulipAppDelegate.h"
#import "RawMessage.h"
#import "UnreadManager.h"
#import "LongPoller.h"
#import "RangePair.h"
#import "PreferencesWrapper.h"
#import "ZUserPresence.h"
#import "LeftSidebarViewController.h"

#import "KeychainItemWrapper.h"

// Models
#import "ZSubscription.h"
#import "ZUser.h"

// AFNetworking
#import "AFJSONRequestOperation.h"

// Categories
#import "UIColor+HexColor.h"

// for md5
#import <CommonCrypto/CommonDigest.h>

// Private category to let us declare "private" member properties
@interface ZulipAPIController ()

@property (nonatomic, retain) NSString *apiKey;

@property (assign) long maxLocalMessageId;

@property (nonatomic, retain) LongPoller *messagesPoller;
@property (nonatomic, retain) LongPoller *metadataPoller;

@property (nonatomic, assign) BOOL messagesPollFailed;

@property (nonatomic, retain) ZulipAppDelegate *appDelegate;

@property (nonatomic, retain) NSMutableArray *rangePairs;

@property (nonatomic, retain) NSMutableDictionary *queuedFlagUpdates;
@property (nonatomic, retain) NSTimer *flagTimer;

// Messages that are loaded in a narrow (e.g. not saved to Core Data)
// are kept here as a reference so we can find them by ID
@property (nonatomic, retain) NSMutableDictionary *ephemeralMessages;

@property (nonatomic, retain) NSMutableDictionary *cachedStreamColors;

@end

NSString * const kLongPollMessageNotification = @"LongPollMessages";
NSString * const kLongPollMessageData = @"LongPollMessageData";
NSString * const kLogoutNotification = @"ZulipLogoutNotification";
NSString * const kLoginNotification = @"ZulipLoginNotification";
NSString * const kPushNotificationMessagePayloadNotification = @"PushNotificationMessagePayload";
NSString * const kPushNotificationMessagePayloadData = @"PushNotificationMessage";


@implementation ZulipAPIController

// Explicitly synthesize so we _-prefix member vars,
// as we override the default getter/setters
@synthesize pointer = _pointer;
@synthesize backgrounded = _backgrounded;
@synthesize realm = _realm;

- (id) init
{
    self = [super init];

    if (self) {
        [self clearSettingsForNewUser:YES];
        [self loadRangesFromFile];

        self.appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
        _unreadManager = [[UnreadManager alloc] init];

        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]
                                             initWithIdentifier:@"ZulipLogin" accessGroup:nil];
        NSString *storedApiKey = [keychainItem objectForKey:(__bridge id)kSecValueData];
        NSString *storedEmail = [keychainItem objectForKey:(__bridge id)kSecAttrAccount];

        [self initPollers];

        if (![storedApiKey isEqualToString:@""]) {
            // We have credentials, so try to reuse them. We may still have to log in if they are stale.
            self.apiKey = storedApiKey;
            self.email = storedEmail;

            [ZulipAPIClient setCredentials:self.email withAPIKey:self.apiKey];

            [[PreferencesWrapper sharedInstance] setDomain:[self domain]];
            _pointer = [[PreferencesWrapper sharedInstance] pointer];
            _fullName = [[PreferencesWrapper sharedInstance] fullName];

            [self registerForMessages];
            [self registerForMetadata];
        }
    }

    return self;
}

- (void)clearSettingsForNewUser:(BOOL)newUser
{
    if (newUser) {
        self.apiKey = @"";
        self.email = @"";
        self.fullName = @"";
        self.fullNameLookupDict = [[NSMutableDictionary alloc] init];
    }
    self.backgrounded = NO;
    self.pointer = -1;
    self.messagesPollFailed = NO;
    self.maxServerMessageId = -1;
    self.maxLocalMessageId = -1;
    self.rangePairs = [[NSMutableArray alloc] init];
    self.cachedStreamColors = [[NSMutableDictionary alloc] init];
    self.queuedFlagUpdates = [[NSMutableDictionary alloc] init];
    self.flagTimer = nil;
}

- (void)initPollers
{
    self.messagesPoller = [[LongPoller alloc] initWithInitialBlock:^(NSDictionary *data) {
        [self messagesPollInitialData:data];
    } andEventBlock:^(NSArray *events) {
        [self messagesPollReceivedMessages:events];
    }];
    [self.messagesPoller registerErrorHandler:^{
        [self messagesPollErrorHandler];
    }];

    self.metadataPoller = [[LongPoller alloc] initWithInitialBlock:^(NSDictionary *data) {
        [self metadataPollInitialData:data];
    } andEventBlock:^(NSArray *events) {
        [self metadataPollEventsReceived:events];
    }];

    [self.metadataPoller registerErrorHandler:^{
        [self metadataPollErrorHandler];
    }];

    // Changing the unique name will force a reload of all database data
    [self.metadataPoller makePersistentWithUniqueName:@"LongLivedMetadata"];

}

- (NSString *)rangesFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"Zulip_MessageRanges.data"];

    return filePath;
}

- (void)loadRangesFromFile
{
    NSString *filePath = [self rangesFilePath];

    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return;
    }

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath];
    self.rangePairs = [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (void)saveRangesToFile
{
    NSString *filePath = [self rangesFilePath];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.rangePairs];
    [data writeToFile:filePath atomically:YES];
}

- (void)applicationWillTerminate
{
    [self saveRangesToFile];
}

- (void)loadUserSettings
{
    // Load initial activity status, etc
}

- (void)login:(NSString *)username password:(NSString *)password result:(void (^) (bool success))result;
{
    if (!username || !password) {
        result(NO);
        return;
    }

    NSDictionary *postFields =  @{@"username": username,
                                  @"password": password};

    [ZulipAPIClient setEmailForDomain:username];

    [[ZulipAPIClient sharedClient] postPath:@"fetch_api_key" parameters:postFields success:^(AFHTTPRequestOperation *operation , id responseObject) {
        NSDictionary *jsonDict = (NSDictionary *)responseObject;

        // If we were previously logged in, log out first
        if ([self loggedIn]) {
            [self logout];
        }

        self.apiKey = jsonDict[@"api_key"];
        self.email = jsonDict[@"email"] ?: username;

        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"ZulipLogin" accessGroup:nil];
        [keychainItem setObject:self.apiKey forKey:(__bridge id)kSecValueData];
        [keychainItem setObject:self.email forKey:(__bridge id)kSecAttrAccount];

        [ZulipAPIClient setCredentials:self.email withAPIKey:self.apiKey];
        [[PreferencesWrapper sharedInstance] setDomain:[self domain]];

        [self registerForMessages];
        [self registerForMetadata];

        result(YES);

        NSNotification *loginNotification = [NSNotification notificationWithName:kLoginNotification
                                                                           object:self
                                                                         userInfo:nil];
        [[NSNotificationCenter defaultCenter] postNotification:loginNotification];

    } failure: ^( AFHTTPRequestOperation *operation , NSError *error ){
        NSLog(@"Failed to fetch_api_key %@", [error localizedDescription]);

        result(NO);
    }];
}

- (void) logout
{
    // Hide any error screens if visible
    [self.appDelegate dismissErrorScreen];

    // Stop pollers
    [self.messagesPoller reset];
    [self.metadataPoller reset];

    BOOL wasLoggedIn = [self loggedIn];

    [self clearSettingsForNewUser:YES];
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]
                                         initWithIdentifier:@"ZulipLogin" accessGroup:nil];
    [keychainItem resetKeychainItem];

    [self.appDelegate reloadCoreData];

    if (wasLoggedIn) {
        NSNotification *logoutNotification = [NSNotification notificationWithName:kLogoutNotification
                                                                           object:self
                                                                         userInfo:nil];
        [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];

        [[ZulipAPIClient sharedClient] logout];
    }
}

- (BOOL)loggedIn
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

- (void)registerForMessages
{
    // Register for all events
    NSDictionary *messagesOpts = @{@"apply_markdown": @"true"};

    [self.messagesPoller registerWithOptions:messagesOpts];
}

- (void)registerForMetadata
{
    // Metadata
    NSArray *event_types = @[@"pointer", @"realm_user", @"subscription", @"update_message", @"update_message_flags", @"realm_domain"];
    NSDictionary *messagesOpts = @{@"apply_markdown": @"true",
                                   @"event_types": [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:event_types options:0 error:nil]
                                                              encoding:NSUTF8StringEncoding],
                                   @"queue_lifespan_secs": @(7 * 24 * 60 * 60)}; // Long-lived queue lives for 1 week

    [self.metadataPoller registerWithOptions:messagesOpts];
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

    [[PreferencesWrapper sharedInstance] setPointer:_pointer];
}

- (void)setPointerFromServer:(long)pointer
{
    if (pointer <= _pointer)
        return;

    [self willChangeValueForKey:@"pointer"];
    _pointer = pointer;
    [self didChangeValueForKey:@"pointer"];

    [[PreferencesWrapper sharedInstance] setPointer:_pointer];
}

- (BOOL)backgrounded
{
    return _backgrounded;
}

- (void)setBackgrounded:(BOOL)backgrounded
{
    if (_backgrounded == backgrounded)
        return;

    // Save range pairs when backgrounded
    if (backgrounded && !_backgrounded) {
        [self saveRangesToFile];
    }

    if (_backgrounded && !backgrounded) {
        NSLog(@"Coming to the foreground!!");
        [self loadRangesFromFile];
        [self loadUsersListFromCoreData];
    }
    _backgrounded = backgrounded;
}

#pragma mark - Loading messages

- (void) loadMessagesAroundAnchor:(int)anchor
                           before:(int)before
                            after:(int)after
                    withOperators:(NarrowOperators *)operators
                  completionBlock:(MessagesDelivered)block
{

    if (operators.isServerOnly) {
        [self loadServerMessagesAroundAnchor:anchor
                                      before:before
                                       after:after
                               withOperators:operators
                             completionBlock:block];
        return;
    }

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

    // We have a list of matching messages from Core Data, and we need to make sure there aren't missing messages
    // on the server between them. We'll check if the first and last messages are within the same range

    BOOL needsServerFetch = NO;

    if (error) {
        NSLog(@"Error fetching results from Core Data for message request! %@ %@", [error localizedDescription], [error userInfo]);
    } else {
        if ([results count] == fetchRequest.fetchLimit) {
            ZMessage *first = [results objectAtIndex:0];
            ZMessage *last = [results lastObject];

            RangePair *firstRange = [RangePair getCurrentRangeOf:[first.messageID intValue] inRangePairs:self.rangePairs];
            RangePair *lastRange = [RangePair getCurrentRangeOf:[last.messageID intValue] inRangePairs:self.rangePairs];

            NSLog(@"Got first %@ and last %@ ranges for first fetched message and last fetched message", firstRange, lastRange);

            if (!firstRange || !lastRange || ![firstRange isEqual:lastRange]) {
                NSLog(@"Got messages across range boundaries, refetching");
                needsServerFetch = YES;
            } else {
                NSLog(@"No extra fetching required, using Core Data messages");
                needsServerFetch = NO;
            }
        } else if (results.count == 0) {
            needsServerFetch = YES;
        }
    }


    if (results.count > 0) {
        block([self rawMessagesFromManaged:results], !needsServerFetch);
    }

    if (!needsServerFetch) return;

    [self loadServerMessagesAroundAnchor:anchor before:before after:after withOperators:operators completionBlock:block];
}

#pragma mark - Zulip API calls

/**
 Load messages from the Zulip API into Core Data
 */
- (void) loadServerMessagesAroundAnchor:(long)anchor
                          before:(NSInteger)before
                           after:(NSInteger)after
                          withOperators:(NarrowOperators *)narrow
                 completionBlock:(MessagesDelivered)block {
    if (!anchor) {
        anchor = self.pointer;
    }

    NSString *narrowParam = @"{}";
    if (narrow)
        narrowParam = [narrow allocAsJSONPayload];

    NSDictionary *fields = @{@"apply_markdown": @"true",
                             @"anchor": @(anchor),
                             @"num_before": @(before),
                             @"num_after": @(after),
                             @"narrow": narrowParam
                             };

    NSLog(@"Getting message: %@", fields);

    [[ZulipAPIClient sharedClient] getPath:@"messages" parameters:fields success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = (NSDictionary *)responseObject;

        if ([NSThread isMainThread]) {
            [self insertMessages:[json objectForKey:@"messages"] saveToCoreData:[narrow isHomeView] withCompletionBlock:block];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self insertMessages:[json objectForKey:@"messages"] saveToCoreData:[narrow isHomeView] withCompletionBlock:block];
            });
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to load old messages: %@", [error localizedDescription]);
    }];
}

- (void)metadataPollInitialData:(NSDictionary *)json
{
    if (json && [json objectForKey:@"pointer"]) {
       [self setPointerFromServer:[[json objectForKey:@"pointer"] longValue]];
        [[PreferencesWrapper sharedInstance] setPointer:self.pointer];
    }

    if (json && [json objectForKey:@"realm_users"]) {
        // Set the full name from realm_users
        // TODO save the whole list properly and use it for presence information
        NSArray *realm_users = [json objectForKey:@"realm_users"];
        for (NSDictionary *person in realm_users) {
            [self addPerson:person andSave:YES];
            if ([[person objectForKey:@"email"] isEqualToString:self.email])
                self.fullName = [person objectForKey:@"full_name"];
        }

        [[PreferencesWrapper sharedInstance] setFullName:self.fullName];
    } else if (![json objectForKey:@"realm_users"])
    {
        [self loadUsersListFromCoreData];
    }

    if (json && [json objectForKey:@"subscriptions"]) {
        NSLog(@"Registered for queue, pointer is %li", self.pointer);
        NSArray *subscriptions = [json objectForKey:@"subscriptions"];
        [self loadSubscriptionData:subscriptions];
    }

    if (json && [json objectForKey:@"realm_domain"]) {
        _realm = [json objectForKey:@"realm_domain"];
    }

    // Set up the home view
    [self.homeViewController initialPopulate];
}

- (void)messagesPollInitialData:(NSDictionary *)json
{
    if (json && [json objectForKey:@"pointer"]) {
        [self setPointerFromServer:[[json objectForKey:@"pointer"] longValue]];
        [[PreferencesWrapper sharedInstance] setPointer:self.pointer];
    }

    if (json && [json objectForKey:@"realm_domain"]) {
        _realm = [json objectForKey:@"realm_domain"];
    }

    self.maxServerMessageId = [[json objectForKey:@"max_message_id"] intValue];
}

- (void)messagesPollReceivedMessages:(NSArray *)events
{
    [self eventsReceived:events fromPoller:self.messagesPoller];
}

- (void)metadataPollEventsReceived:(NSArray *)events
{
    // We use our long-lived metadata queue only in the event of
    // of our main message queue having been garbage collected.
    // In that event, once we've drained our missed events, we
    // go back to ignoring them from this queue
    if (self.messagesPollFailed) {
        [self eventsReceived:events fromPoller:self.metadataPoller];
        self.messagesPollFailed = NO;
    }
}

- (void)eventsReceived:(NSArray *)events fromPoller:(LongPoller *)poller {
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    long oldServerMessageId = self.maxServerMessageId;

    for (NSDictionary *event in events) {
        NSString *eventType = [event objectForKey:@"type"];

        if ([eventType isEqualToString:@"pointer"]) {
            long newPointer = [[event objectForKey:@"pointer"] longValue];

            self.pointer = newPointer;
        } else if ([eventType isEqualToString:@"update_message_flags"]) {
            BOOL all = [[event objectForKey:@"all"] boolValue];

            NSString *flag = [event objectForKey:@"flag"];
            NSArray *messageIDs = [event objectForKey:@"messages"];
            NSString *operation = [event objectForKey:@"operation"];

            [self updateMessages:messageIDs withFlag:flag operation:operation all:all];
        } else if ([eventType isEqualToString:@"message"]) {
            NSMutableDictionary *msg = [[event objectForKey:@"message"] mutableCopy];
            [msg setValue:[event objectForKey:@"flags"] forKey:@"flags"];
            [messages addObject:msg];

            long msgId = [[msg objectForKey:@"id"] longValue];
            self.maxServerMessageId = MAX(self.maxServerMessageId, msgId);
        } else if ([eventType isEqualToString:@"presence"]) {
            NSDictionary *presence = [event objectForKey:@"presence"];
            NSString *email = event[@"email"];

            for (NSString *client in presence) {
                [self updatePresence:email withStatus:presence[client]];
            }
        } else if ([eventType isEqualToString:@"subscriptions"]) {
            BOOL needToSave = NO;
            if ([event[@"op"] isEqualToString:@"add"]) {
                needToSave = YES;

                NSMutableArray *subscriptions = [NSMutableArray new];
                for (NSDictionary *dict in event[@"subscriptions"]) {
                    ZSubscription *subscription = [[ZSubscription alloc] initWithDictionary:dict];
                    [subscriptions addObject:subscription];
                }

            } else if ([event[@"op"] isEqualToString:@"remove"]) {
                needToSave = YES;

                NSMutableArray *subscriptionNames = [NSMutableArray new];
                for (NSDictionary *dict in event[@"subscriptions"]) {
                    [subscriptionNames addObject:dict[@"name"]];
                }

                NSPredicate * predicate = [NSPredicate predicateWithFormat:@"name IN %@", subscriptionNames];
                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
                fetchRequest.predicate = predicate;

                NSError *error = nil;
                NSArray *results = [self.appDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                if (error) {
                    NSLog(@"Error fetching ZSubscriptions: %@, %@", [error localizedDescription], [error userInfo]);
                    return;
                }

                for (ZSubscription *subscription in results) {
                    [self.appDelegate.managedObjectContext deleteObject:subscription];
                }
            }

            if (needToSave) {
                NSError *error = nil;
                [self.appDelegate.managedObjectContext save:&error];
                if (error) {
                    NSLog(@"Error saving ZSubscription: %@ %@", [error localizedDescription], [error userInfo]);
                    return;
                }

                LeftSidebarViewController *leftSidePanel = (LeftSidebarViewController *)self.appDelegate.sidePanelController.leftPanel;
                if ([leftSidePanel isKindOfClass:[LeftSidebarViewController class]]) {
                    [leftSidePanel reset];
                }
            }
        }

        // Insert batches of message update events as soon as we receive them, as
        // further events (update pointer for example) might depend on us having
        // already added the messages to our message list
        if (![eventType isEqualToString:@"message"] && [messages count] > 0) {
            [self insertMessagesFromServer:messages withOldMaxServerId:oldServerMessageId];
            messages = [[NSMutableArray alloc] init];
            oldServerMessageId = self.maxServerMessageId;
        }
    }

    if ([messages count] > 0) {
        [self insertMessagesFromServer:messages withOldMaxServerId:oldServerMessageId];
    }
}

- (void)insertMessagesFromServer:(NSArray *)messages withOldMaxServerId:(long)oldServerMessageId
{
    // If we're not up to date (e.g. our latest message is not the max msg id,
    // and the user is still reading scrollback, then don't load the new messages,
    // but just keep the new maxMessageId
    if (self.maxLocalMessageId < oldServerMessageId) {
        return;
    }

    [self insertMessages:messages saveToCoreData:YES withCompletionBlock:^(NSArray *finishedMessages, BOOL isFinished) {
        NSNotification *longPollMessages = [NSNotification notificationWithName:kLongPollMessageNotification
                                                                         object:self
                                                                       userInfo:@{kLongPollMessageData: finishedMessages}];
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter postNotification:longPollMessages];
    }];
}

- (void)messagesPollErrorHandler
{
    // If we lose our messages poller, we simply restart our polling and re-fetch messages
    // around the pointer
    [self clearSettingsForNewUser:NO];

    self.messagesPollFailed = YES;

    NSLog(@"Doing messages reset");
    [self.appDelegate clearNarrowWithAnimation:NO];

    [self.homeViewController initialPopulate];

    [self.messagesPoller reset];
    [self registerForMessages];
}

- (void)metadataPollErrorHandler
{
    // If we lose our long-lived metadata queue, we force a full-reset and clear the database completely. Starting from scratch
    NSString *email = self.email;
    NSString *apiKey = self.apiKey;

    NSLog(@"Doing full reset");
    [self.metadataPoller reset];
    [self logout];

    self.apiKey = apiKey;
    self.email = email;

    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"ZulipLogin" accessGroup:nil];
    [keychainItem setObject:self.apiKey forKey:(__bridge id)kSecValueData];
    [keychainItem setObject:self.email forKey:(__bridge id)kSecAttrAccount];

    [ZulipAPIClient setCredentials:self.email withAPIKey:self.apiKey];
    [[PreferencesWrapper sharedInstance] setDomain:[self domain]];

    [self registerForMessages];
    [self registerForMetadata];
}

- (void)updateMessages:(NSArray *)messageIDs withFlag:(NSString *)flag operation:(NSString *)op all:(BOOL)all
{
    if (all) {
        // TODO handle bankruptcy
        return;
    }

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZMessage"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"messageID IN %@", [NSSet setWithArray:messageIDs]];

    NSError *error = nil;
    NSArray *messages = [[self.appDelegate managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"Error fetching messages to update from Core Data: %@ %@", [error localizedDescription], [error userInfo]);
        return;
    }

    // Update Core Data-backed messages
    NSMutableArray *rawMessagesToUpdate = [[NSMutableArray alloc] init];
    for (ZMessage *msg in messages) {
        // Update raw msg attached to core data
        RawMessage *raw = msg.linkedRawMessage;

        if (raw) {
            [rawMessagesToUpdate addObject:raw];
        }
    }

    // Update any RawMessage-only messages (messages loaded in a narrow, not saved to core data)
    for (NSString *msgId in messageIDs) {
        NSNumber *numId = [NSNumber numberWithInt:[msgId intValue]];
        if ([self.ephemeralMessages objectForKey:numId]) {
            [rawMessagesToUpdate addObject:[self.ephemeralMessages objectForKey:numId]];
        }
    }

    for (RawMessage *raw in rawMessagesToUpdate) {
        raw.disableUpdates = YES;
        if ([op isEqualToString:@"add"]) {
            // We handle read flags explicitly so we mark them
            // as read in our unread manager
            if ([flag isEqualToString:@"read"]) {
                [raw setRead:YES];
            } else {
                [raw addMessageFlag:flag];
            }
        } else if ([op isEqualToString:@"remove"]) {
            [raw removeMessageFlag:flag];
        }
        raw.disableUpdates = NO;
    }

    if ([messages count] > 0) {
        error = nil;
        [[self.appDelegate managedObjectContext] save:&error];
        if (error) {
            NSLog(@"Failed to save flag updates: %@ %@", [error localizedDescription], [error userInfo]);
        }
    }
}

- (void)sendMessageFlagsUpdated:(RawMessage *)message withOperation:(NSString *)operation andFlag:(NSString *)flag
{
    if (self.flagTimer) {
        [self.flagTimer invalidate];
    }

    self.flagTimer = [NSTimer timerWithTimeInterval:2.0 target:self selector:@selector(sendMessageFlagsTimerExpired) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.flagTimer forMode:@"NSDefaultRunLoopMode"];

    // Store this flag update in our queued flag data structure:
    // { flag: { add:    [message, message, message],
    //           remove: [message, ...] }
    // }
    NSMutableDictionary *opDict;
    if (![self.queuedFlagUpdates objectForKey:flag]) {
        opDict = [NSMutableDictionary dictionaryWithDictionary:@{operation: [[NSMutableArray alloc] init]}];
        [self.queuedFlagUpdates setObject:opDict forKey:flag];
    } else {
        opDict = [self.queuedFlagUpdates objectForKey:flag];
        if (![opDict objectForKey:operation]) {
            [opDict setObject:[[NSMutableArray alloc] init] forKey:operation];
        }
    }

    [[opDict objectForKey:operation] addObject:message.messageID];
}

- (void)sendMessageFlagsTimerExpired
{
    if (self.queuedFlagUpdates && [self.queuedFlagUpdates count] > 0) {
        for (NSString *flag in self.queuedFlagUpdates) {
            NSDictionary *updates = [self.queuedFlagUpdates valueForKey:flag];

            for (NSString *op in updates) {
                NSArray *messageIDs = [updates objectForKey:op];

                NSData *data = [NSJSONSerialization dataWithJSONObject:messageIDs options:0 error:nil];
                NSDictionary *opts = @{@"messages": [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
                                       @"flag": flag,
                                       @"op": op};
                [[ZulipAPIClient sharedClient] postPath:@"messages/flags" parameters:opts success:nil failure:^(AFHTTPRequestOperation *afop, NSError *error) {
                    NSLog(@"Failed to update message flags %@ %@", [error localizedDescription], [error userInfo]);
                }];
            }
        }
        self.queuedFlagUpdates = [[NSMutableDictionary alloc] init];
    }
    self.flagTimer = nil;
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
        ZSubscription *sub = [oldSubsDict objectForKey:subName];
        if (!sub) {
            NSLog(@"Got invalid subscription that we are trying to remove!");
            NSAssert2(NO, @"Invalid subscription to remove: %@, %@", subName, oldSubsDict);
            continue;
        }
        [[self.appDelegate managedObjectContext] deleteObject:sub];
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

        if (!saveToCD) {
            [self.ephemeralMessages setObject:msg forKey:msg.messageID];
        }
    }

    // Pass the downloaded messages back to whichever message list asked for it
    block(rawMessages, YES);

    if (!saveToCD) {
        return;
    }

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

        msg.linkedRawMessage = rawMsg;
        rawMsg.linkedZMessage = msg;

        [zmessages addObject:msg];
    }

    error = nil;
    [[self.appDelegate managedObjectContext] save:&error];
    if (error) {
        NSLog(@"Error saving new messages: %@ %@", [error localizedDescription], [error userInfo]);
    }

    if ([rawMessages count] > 0) {
        // Update our message range data structure
        RawMessage *first = [rawMessages objectAtIndex:0];
        RawMessage *last = [rawMessages lastObject];
        long firstId = [first.messageID longValue];
        long lastId = [last.messageID longValue];

        if ([rawMessages count] == 1 && self.maxLocalMessageId > -1) {
            // HACK for 1 message that we get from long polling
            // When we long poll, we know that there's no missing message
            // between the new messages and our latest loaded message
            // so we construct a 2-item range with the latest item
            if (firstId == self.maxLocalMessageId) {
                // It's possible that on resuming, we get new messages both from
                // the long-poll and getOldMessages. If so, just ignore the later call
                return;
            }
            firstId = self.maxLocalMessageId;
        }

        RangePair *rangePair = [[RangePair alloc] initWithStart:firstId andEnd:lastId];
        [RangePair extendRanges:self.rangePairs withRange:rangePair];

        self.maxLocalMessageId = MAX(self.maxLocalMessageId, [last.messageID longValue]);
    }
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

    [msg setMessageFlags:[NSSet setWithArray:[msgDict objectForKey:@"flags"]]];

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
    if ([personDict objectForKey:@"full_name"]  && [personDict objectForKey:@"email"])
    {
        [self.fullNameLookupDict setObject:[personDict objectForKey:@"full_name"] forKey:[personDict objectForKey:@"email"]];
    }
    //TODO: have a system for non-gravatar avatars when personDict['avatar_url'] isn't set.
    NSString * email = [personDict objectForKey:@"email"];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ZUser"];
    request.predicate = [NSPredicate predicateWithFormat:@"email == %@", email];

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
        if (![personDict objectForKey:@"email"]) {
            NSLog(@"Tried to add a new person without an email?! %@", personDict);
            return nil;
        }

        user = [NSEntityDescription insertNewObjectForEntityForName:@"ZUser" inManagedObjectContext:[self.appDelegate managedObjectContext]];
    }
    NSArray *stringProperties = @[@"email", @"full_name"];
    for (NSString *prop in stringProperties) {
        // Use KVC to set the property value by the string name
        [user setValue:[personDict valueForKey:prop] forKey:prop];
    }

    // if the avatar is specified use it. Otherwise set it to the gravatar url.
    if ([personDict valueForKey:@"avatar_url"]) {
        [user setValue:[personDict valueForKey:@"avatar_url"] forKey:@"avatar_url"];
    } else {
        [user setValue:[self gravatarUrl:user.email] forKey:@"avatar_url"];
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

- (void)updatePresence:(NSString *)email withStatus:(NSDictionary *)presence
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ZUserPresence"];
    request.predicate = [NSPredicate predicateWithFormat:@"user.email == %@ && client == %@", email, presence[@"client"]];

    ZulipAppDelegate *delegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSArray *results = [[delegate managedObjectContext] executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error fetching ZUserPresences: %@ %@", [error localizedDescription], [error userInfo]);

        return;
    }

    ZUserPresence *zpresence = nil;
    if ([results count] > 0) {
        if ([results count] > 1) {
            NSLog(@"Found more than one email/client row for %@!", email);
        }

        zpresence = [results objectAtIndex:0];
    } else {
        zpresence = [NSEntityDescription insertNewObjectForEntityForName:@"ZUserPresence" inManagedObjectContext:[delegate managedObjectContext]];
        zpresence.client = presence[@"client"];
    }

    zpresence.status = presence[@"status"];
    zpresence.timestamp = presence[@"timestamp"];

    error = nil;
    [[delegate managedObjectContext] save:&error];
    if (error) {
        NSLog(@"Error saving ZUserPresences: %@ %@", [error localizedDescription], [error userInfo]);
    }

}

- (NSString *)gravatarUrl:(NSString *)email
{

    email = [[email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    const char *ptr = [email UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(ptr, strlen(ptr), md5Buffer);

    NSMutableString *gravatarHash = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [gravatarHash appendFormat:@"%02x",md5Buffer[i]];

    return [NSString stringWithFormat:
            @"https://secure.gravatar.com/avatar/%@?d=identicon",
            gravatarHash];
}

- (ZUser*)getPersonFromCoreDataWithEmail:(NSString *)email
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZUser"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"email == %@", email];
    fetchRequest.fetchLimit = 1;

    NSError *error = nil;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"Failed to fetch user profile: %@ %@", [error localizedDescription], [error userInfo]);
    }
    if ([results count] > 0) {
        return [results objectAtIndex:0];
    }
    return nil;
}

- (void)loadUsersListFromCoreData
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZUser"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"email.length>0"];
    NSError *error = nil;
    NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"Failed to fetch user list: %@ %@", [error localizedDescription], [error userInfo]);
    }
    if ([results count] > 0) {
        for (ZUser *result in results)
        {
            [self.fullNameLookupDict setObject:result.full_name forKey:result.email];
        }
    }
}

- (NSArray *)rawMessagesFromManaged:(NSArray *)messages
{
    NSMutableArray *rawMessages = [[NSMutableArray alloc] init];
    for (ZMessage *msg in messages) {
        RawMessage *raw = [RawMessage allocFromZMessage:msg];
        msg.linkedRawMessage = raw;
        [rawMessages addObject:raw];
        [self.unreadManager handleIncomingMessage:raw];
    }
    return rawMessages;
}

#pragma mark - Core Data Getters

- (UIColor *)streamColor:(NSString *)name withDefault:(UIColor *)defaultColor {
    if ([self.cachedStreamColors objectForKey:name]) {
        return [self.cachedStreamColors objectForKey:name];
    }

    // Loading color from Core Data has to be on the main thread, so we pass the resulting UIColor
    // back out of the block
    __block UIColor *color;

    void (^fetchBlock)(void) = ^ {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
        request.predicate = [NSPredicate predicateWithFormat:@"name = %@", name];

        NSError *error = nil;
        NSArray *results = [[self.appDelegate managedObjectContext] executeFetchRequest:request error:&error];
        if (error) {
            NSLog(@"Error fetching subscription to get color: %@, %@", [error localizedDescription], [error userInfo]);
            color = defaultColor;
            return;
        } else if ([results count] == 0) {
            NSLog(@"Error loading stream data to fetch color, %@", name);
            color = defaultColor;
            return;
        }

        ZSubscription *sub = [results objectAtIndex:0];
        color = [UIColor colorWithHexString:sub.color defaultColor:defaultColor];
    };

    // Calling dispatch_sync from the main thread results in a deadlock,
    // so only use dispatch_sync if we're on a background thread
    if ([NSThread isMainThread]) {
        fetchBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            fetchBlock();
        });
    }

    if (![color isEqual:defaultColor]) {
        [self.cachedStreamColors setObject:color forKey:name];
    }
    return color;
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
