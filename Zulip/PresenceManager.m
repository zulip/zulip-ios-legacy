//
//  PresenceManager.m
//  Zulip
//
//  Created by Leonardo Franchi on 12/31/13.
//
//

#import "PresenceManager.h"

#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"
#import "ZulipAppDelegate.h"
#import "ZUserPresence.h"

static double POLL_INTERVAL_SECS = 50.0;

@interface PresenceManager ()

@property (assign, nonatomic) BOOL active;

@end

@implementation PresenceManager

- (id)init
{
    self = [super init];
    if (self) {
        self.active = NO;

        [[NSNotificationCenter defaultCenter] addObserverForName:kLoginNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self didLogIn];
                                                      }];


        [[NSNotificationCenter defaultCenter] addObserverForName:kLogoutNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self loggedOut];
                                                      }];

        if ([[ZulipAPIController sharedInstance] loggedIn]) {
            [self startPolling];
        }
    }
    return self;
}

- (void)didLogIn
{
    [self startPolling];
}

- (void)loggedOut
{
    [self stopPolling];
}

- (void)startPolling
{
    if (self.active) {
        return;
    }
    self.active = YES;

    [self sendPresenceUpdates];
}

- (void)stopPolling
{
    if (!self.active) {
        return;
    }

    self.active = NO;
}

- (void)sendPresenceUpdates
{
    if (!self.active) {
        return;
    }

    NSDictionary *params = @{@"status": @"active", @"new_user_input": @"true"};
    [[ZulipAPIClient sharedClient] postPath:@"users/me/presence" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *data = (NSDictionary *)responseObject;

        // Update ZUserPresence info
        [self updateUserPresences:[data objectForKey:@"presences"]];

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to send presence information: %@, %@", [error localizedDescription], [error userInfo]);
    }];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(POLL_INTERVAL_SECS * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self sendPresenceUpdates];
    });
}

- (void)updateUserPresences:(NSDictionary *)presences
{
    // Update-and-insert presence information
    // 1. Fetch all presence records for the users we have new presences for
    // 2. Build dict of user+client info
    // 3. Update or insert new UserPresence rows
    // 4. Save
    NSArray *userEmails = [presences allKeys];

    // TODO batching for large realms
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"ZUserPresence"];
    request.predicate = [NSPredicate predicateWithFormat:@"(user.email IN %@)", userEmails];

    ZulipAppDelegate *delegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSArray *results = [[delegate managedObjectContext] executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Error fetching ZUserProfiles: %@ %@", [error localizedDescription], [error userInfo]);

        return;
    }

    NSMutableDictionary *foundUsers = [[NSMutableDictionary alloc] init];
    for (ZUserPresence *userPresence in results) {
        if (![foundUsers objectForKey:userPresence.user.email]) {
            foundUsers[userPresence.user.email] = [[NSMutableDictionary alloc] initWithDictionary:@{userPresence.client: userPresence}];
            continue;
        }

        foundUsers[userPresence.user.email][userPresence.client] = userPresence;
    }

    for (NSString *email in presences) {
        for (NSString *client in presences[email]) {
            ZUserPresence *userPresence = nil;
            NSDictionary *clientDict = [foundUsers objectForKey:email];
            if (clientDict && [clientDict objectForKey:client]) {
                userPresence = clientDict[client];
            }

            if (!userPresence) {
                ZUser *user = [[ZulipAPIController sharedInstance] getPersonFromCoreDataWithEmail:email];
                if (!user) {
                    continue;
                }

                // Create a new ZUserPresence
                userPresence = [NSEntityDescription insertNewObjectForEntityForName:@"ZUserPresence" inManagedObjectContext:[delegate managedObjectContext]];
                // TODO pre-fetch in 1 query, not individually
                userPresence.user = user;
                userPresence.client = client;
            }

            if (![userPresence.timestamp isEqualToNumber:presences[email][client][@"timestamp"]]) {
                userPresence.timestamp = presences[email][client][@"timestamp"];
            }
            if (![userPresence.status isEqualToString:presences[email][client][@"status"]]) {
                userPresence.status = presences[email][client][@"status"];
            }
        }
    }

    error = nil;
    [[delegate managedObjectContext] save:&error];
    if (error) {
        NSLog(@"Error saving ZUserPresences: %@ %@", [error localizedDescription], [error userInfo]);
    }
}

@end
