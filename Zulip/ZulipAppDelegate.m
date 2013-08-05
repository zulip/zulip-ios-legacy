#import "ZulipAppDelegate.h"
#import "KeychainItemWrapper.h"
#import "NSString+Encode.h"
#import "ZulipAPIClient.h"
#import "ZulipAPIController.h"
#import "StreamsSidebarController.h"
#import "NarrowViewController.h"

// AFNetworking
#import "AFNetworkActivityIndicatorManager.h"
#import "AFJSONRequestOperation.h"

// Crashlytics
#import <Crashlytics/Crashlytics.h>

// JASidePanels
#import "JASidePanelController.h"

@interface ZulipAppDelegate ()

@property (nonatomic, retain) NSMutableDictionary *narrows;

@end

@implementation ZulipAppDelegate

@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Crashlytics startWithAPIKey:@"7c523eb4efdbd264d6d4a7403ee7a683b733a9bd"];

    self.errorViewController = [[ErrorViewController alloc] init];

    self.sidePanelController = [[JASidePanelController alloc] init];
    self.sidePanelController.shouldDelegateAutorotateToVisiblePanel = NO;
    self.sidePanelController.panningLimitedToTopViewController = NO;

    self.homeViewController = [[HomeViewController alloc] init];
    // Bottom padding so you can see new messages arrive.
    self.homeViewController.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 200.0, 0.0);
    self.navController = [[UINavigationController alloc] initWithRootViewController:self.homeViewController];

    [self.narrows setObject:self.homeViewController forKey:(id)self.homeViewController.operators];

    self.sidePanelController.centerPanel = self.navController;

    StreamsSidebarController *sidebar = [[StreamsSidebarController alloc] init];
    self.sidePanelController.leftPanel = sidebar;

    // Connect the API controller to the home view, and connect to the Zulip API
    [[ZulipAPIController sharedInstance] setHomeViewController:self.homeViewController];

    if (![[ZulipAPIController sharedInstance] loggedIn]) {
        // No credentials stored; we need to log in.
        self.loginViewController = [[LoginViewController alloc] init];
        [self.navController pushViewController:self.loginViewController animated:YES];
    }

    [[self window] setRootViewController:self.sidePanelController];

    // Set out NSURLCache settings
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:20 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];

    [self.window makeKeyAndVisible];

    return YES;
}

- (void)dismissLoginScreen
{
//    [self.loginViewController.view removeFromSuperview];
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

- (void)reloadCoreData
{
    __managedObjectContext = 0;
    __managedObjectModel = 0;
    __persistentStoreCoordinator = 0;
}

- (void)narrowWithOperators:(NarrowOperators *)narrowOperators;
{
    NarrowViewController *narrowController;
    if ([self.narrows objectForKey:narrowOperators]) {
        narrowController = [self.narrows objectForKey:narrowOperators];
    } else {
        narrowController = [[NarrowViewController alloc] initWithOperators:narrowOperators];
        [self.narrows setObject:narrowController forKey:(id)narrowOperators];
    }

    if ([self isNarrowed])
        [self.navController popToRootViewControllerAnimated:NO];


    [self.navController pushViewController:narrowController animated:NO];
    [self.sidePanelController toggleLeftPanel:self];
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
    int i = [controllers count] - 1;
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
        [self.navController popToRootViewControllerAnimated:animated];
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
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    [[ZulipAPIController sharedInstance] setBackgrounded:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
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
        NSLog(@"Error initializing persistent sqlite store! %@, %@", [error localizedDescription], [error userInfo]);
        abort();
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
