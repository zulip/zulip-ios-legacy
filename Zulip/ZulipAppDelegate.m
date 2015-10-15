#import "ZulipAppDelegate.h"
#import "KeychainItemWrapper.h"
#import "NSString+Encode.h"
#import "ZulipAPIClient.h"
#import "ZulipAPIController.h"
#import "LeftSidebarViewController.h"
#import "RightSidebarViewController.h"
#import "NarrowViewController.h"
#import "AboutViewController.h"
#import "PresenceManager.h"
#import "NSArray+Blocks.h"

// AFNetworking
#import "AFNetworkActivityIndicatorManager.h"
#import "AFJSONRequestOperation.h"

// JASidePanels
#import "JASidePanelController.h"

// HockeySDK
#import <HockeySDK/HockeySDK.h>

@interface ZulipAppDelegate ()

@property (nonatomic, retain) NSMutableDictionary *narrows;
@property (nonatomic, retain) NSData *cachedAPNSToken;

@end

@implementation ZulipAppDelegate

@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

-(id) init
{
    self = [super init];
    if (self) {
        self.wakingFromBackground = NO;
        self.notifiedWithMessages = @[];
        self.narrows = [[NSMutableDictionary alloc] init];
    }

    return self;
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"8568832c4be84968884d77c7a27cb6d7"];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
    
    // Set up our views
    self.errorViewController = [[ErrorViewController alloc] init];

    self.sidePanelController = [[JASidePanelController alloc] init];
    self.sidePanelController.shouldDelegateAutorotateToVisiblePanel = NO;
    self.sidePanelController.panningLimitedToTopViewController = NO;

    self.homeViewController = [[HomeViewController alloc] init];
    self.navController = [[UINavigationController alloc] initWithRootViewController:self.homeViewController];

    [self.narrows setObject:self.homeViewController forKey:(id)self.homeViewController.operators];

    self.sidePanelController.centerPanel = self.navController;

    LeftSidebarViewController *leftSidebar = [[LeftSidebarViewController alloc] initWithNibName:@"LeftSidebarViewController" bundle:nil];
    self.sidePanelController.leftPanel = leftSidebar;

    [[NSNotificationCenter defaultCenter] addObserverForName:kLoginNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      [self sendCachedAPNSToken];
                                                  }];
    RightSidebarViewController *rightSidebar = [[RightSidebarViewController alloc] init];
    self.sidePanelController.rightPanel = rightSidebar;

    // Connect the API controller to the home view, and connect to the Zulip API
    [[ZulipAPIController sharedInstance] setHomeViewController:self.homeViewController];

    if (![[ZulipAPIController sharedInstance] loggedIn]) {
        // No credentials stored; we need to log in.
        self.loginViewController = [[LoginViewController alloc] init];
        self.sidePanelController.recognizesPanGesture = NO;
        [self.navController pushViewController:self.loginViewController animated:YES];
    }

    [[self window] setRootViewController:self.sidePanelController];

    // Set out NSURLCache settings
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:20 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];

    // Register with APNS for push notifications
    UIRemoteNotificationType allowedNotifications = UIRemoteNotificationTypeAlert |
                                                    UIRemoteNotificationTypeSound |
                                                    UIRemoteNotificationTypeBadge;

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)allowedNotifications categories:nil]];
    }
    else
    {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:allowedNotifications];
    }

    if ([launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey]) {
        // We were launched from a push notification
        NSDictionary *info_dict = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        [self handlePushNotification:info_dict];
    }

    // Set the app badge to 0 when launching
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

    // Start presence poller
    (void)[[PresenceManager alloc] init];

    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserverForName:kLogoutNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      [self loggedOut];
                                                  }];

    return YES;
}

- (void)dismissLoginScreen
{
    self.sidePanelController.recognizesPanGesture = YES;
    [self.navController popViewControllerAnimated:YES];
}

- (void)showErrorScreen:(NSString *)errorMessage
{
    if ([self.window.subviews containsObject:self.errorViewController.view]) {
        return;
    }

    [self.window addSubview:self.errorViewController.view];
    self.errorViewController.errorMessage.text = errorMessage;
}

- (void)dismissErrorScreen
{
    [self.errorViewController.view removeFromSuperview];
}

-(void)showAboutScreen
{
    AboutViewController *about = [[AboutViewController alloc] initWithNibName:@"AboutView" bundle:nil];
    [self.navController pushViewController:about animated:YES];
}

- (void)reloadCoreData
{
    __managedObjectContext = 0;
    __managedObjectModel = 0;
    __persistentStoreCoordinator = 0;
}

- (void)loggedOut {
    [self.navController setViewControllers:@[self.homeViewController] animated:NO];
    self.narrows = [[NSMutableDictionary alloc] init];
}

#pragma mark - Narrowing

- (void)narrowWithOperators:(NarrowOperators *)narrowOperators;
{
    NarrowViewController *narrowController;
    if ([self.narrows objectForKey:narrowOperators]) {
        narrowController = [self.narrows objectForKey:narrowOperators];
    } else {
        narrowController = [[NarrowViewController alloc] initWithOperators:narrowOperators];
        [self.narrows setObject:narrowController forKey:(id)narrowOperators];
    }
    [self.navController setViewControllers:@[narrowController] animated:YES];
    [self.sidePanelController _placeButtonForLeftPanel];

    if (self.sidePanelController.state == JASidePanelLeftVisible) {
        [self.sidePanelController toggleLeftPanel:self];
    }
}

- (void)narrowWithOperators:(NarrowOperators *)narrow thenDisplayId:(long)messageId
{
    [self narrowWithOperators:narrow];
    NarrowViewController *narrowViewController = (NarrowViewController *)self.navController.topViewController;
    [narrowViewController scrollToMessageID:messageId];
}

- (BOOL)isNarrowed
{
    return [[self.navController visibleViewController] isKindOfClass:[NarrowViewController class]];

}

- (NarrowOperators *)currentNarrow
{
    // There may be a full-screen window like the compose controller on top, so we find the top controller
    // that is a message list.
    NSArray *controllers = [self.navController viewControllers];
    int i = (int)[controllers count] - 1;
    for (; i >= 0; i--) {
        if ([[controllers objectAtIndex:i] isKindOfClass:[StreamViewController class]])
            break;
    }
    StreamViewController *messageController = (StreamViewController *)[controllers objectAtIndex:i];
    return messageController.operators;
}

- (void)clearNarrowWithAnimation:(BOOL)animated
{
    if ([self isNarrowed]) {
        [self.navController setViewControllers:@[self.homeViewController] animated:YES];
        [self.sidePanelController toggleLeftPanel:self];
    }
}

#pragma mark - UIApplicationDelegate

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
    [[ZulipAPIController sharedInstance] setBackgrounded:YES];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    self.wakingFromBackground = YES;

    // Set the app badge to 0 when coming to front
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

    [[ZulipAPIController sharedInstance] setBackgrounded:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    self.wakingFromBackground = NO;

    if ([self.navController.topViewController respondsToSelector:@selector(initialPopulate)]) {
        [(StreamViewController *)self.navController.topViewController initialPopulate];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    [[ZulipAPIController sharedInstance] applicationWillTerminate];
}

#pragma mark - APNS

- (void)sendCachedAPNSToken
{
    if (!self.cachedAPNSToken || ![[ZulipAPIController sharedInstance] loggedIn]) {
        return;
    }

    [self application:[UIApplication sharedApplication] didRegisterForRemoteNotificationsWithDeviceToken:self.cachedAPNSToken];
    self.cachedAPNSToken = nil;
}

#ifdef __IPHONE_8_0
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    //register to receive notifications
    [application registerForRemoteNotifications];
}
#endif

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    if (![[ZulipAPIController sharedInstance] loggedIn]) {
        NSLog(@"Got APNS token before login completed, storing");
        self.cachedAPNSToken = deviceToken;
        return;
    }

    // mark b64 as __block __weak so it sticks around after this method is done executing (since the block passed to NSNotification
    // references is).
    __block __weak NSString *b64 = [deviceToken base64Encoding];

    if (![ZulipAPIClient sharedClient] || !b64) {
        NSLog(@"Got null ZulipAPIClient (%@) or b64 device token: %@, wtf?", [ZulipAPIClient sharedClient], b64);
        return;
    }

    [[ZulipAPIClient sharedClient] postPath:@"users/me/apns_device_token" parameters:@{@"token": b64, @"appid": [[NSBundle mainBundle] bundleIdentifier]} success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to send APNS device token to Zulip servers %@ %@", [error localizedDescription], [error userInfo]);
    }];

    // Remove our token from the server when logging out
    // Only do this removal once, and then unregister the notification that we set up
    __block __weak id observer =
        [[NSNotificationCenter defaultCenter]
            addObserverForName:kLogoutNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
                        [[UIApplication sharedApplication] unregisterForRemoteNotifications];

                        if (!b64) {
                            return;
                        }

                        [[ZulipAPIClient sharedClient] deletePath:@"/users/me/apns_device_token" parameters:@{@"token": b64} success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  NSLog(@"Failed to delete APNS token from Zulip servers %@ %@", [error localizedDescription], [error userInfo]);
                              }];

                        [[NSNotificationCenter defaultCenter] removeObserver:observer name:kLogoutNotification object:nil];
          }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"Failed to register for remote notifications: %@ %@", [error localizedDescription], [error userInfo]);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [self handlePushNotification:userInfo];
}

- (void)handlePushNotification:(NSDictionary *)zulipInfoDict
{
    if (self.wakingFromBackground) {
        NSDictionary *data = [zulipInfoDict objectForKey:@"zulip"];
        if (data) {
            NSArray *messageIDs = [data objectForKey:@"message_ids"];
            if (messageIDs) {
                messageIDs = [messageIDs map:^id(id obj) {
                    return [NSNumber numberWithLongLong:[(NSString *)obj longLongValue]];
                }];
                self.notifiedWithMessages = messageIDs;
            }
        }
    }
}

#pragma mark - Core Data

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext {
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }

    return __managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    __managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];

    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }

    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];

    NSString *sqliteDb = [NSString stringWithFormat:@"Zulip-%@.sqlite", [[ZulipAPIController sharedInstance] domain]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:sqliteDb];

    NSDictionary *options = @{
                              NSInferMappingModelAutomaticallyOption : @(YES),
                              NSMigratePersistentStoresAutomaticallyOption: @(YES)
                              };

    NSError *error = nil;
    [__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
    if (error) {

        // TODO HACK
        // One time hack to remove data storage on migration failure so we still launch
        error = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]]) {
            if (![[NSFileManager defaultManager] removeItemAtPath:[storeURL path] error:&error]) {
                NSLog(@"Failed deleting sqlite file at %@: %@, %@", [storeURL path], error, [error userInfo]);
                abort();
            }

            NSLog(@"Failed to migrate, removed SQLite file and trying again");
        }

        // Try once more to open our persistent store coordinator
        [__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
        if (error) {
            NSLog(@"Error initializing persistent sqlite store! %@, %@", [error localizedDescription], [error userInfo]);
            abort();
        }
    }

    NSLog(@"SQLite URL: %@", storeURL);

    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
