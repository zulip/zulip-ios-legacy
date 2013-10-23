#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "HomeViewController.h"
#import "ErrorViewController.h"
#import "AFHTTPRequestOperation.h"
#import "JASidePanelController.h"
#import "NarrowOperators.h"

@interface ZulipAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate>

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UITabBarController *tabBarController;
@property (nonatomic, retain) UINavigationController *navController;
@property (nonatomic, retain) JASidePanelController *sidePanelController;
@property (nonatomic, retain) LoginViewController *loginViewController;
@property (nonatomic, retain) HomeViewController *homeViewController;
@property (nonatomic, retain) ErrorViewController *errorViewController;

// Push notifications
@property (nonatomic, assign) BOOL wakingFromBackground;
// List of NSNumber * Message IDs that were included in the push notification update
@property (nonatomic, retain) NSArray *notifiedWithMessages;

// Core Data bits
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void) showErrorScreen:(NSString *)errorMessage;
- (void) dismissErrorScreen;
- (void) dismissLoginScreen;
- (void) showAboutScreen;

// Narrowing
- (void) narrowWithOperators:(NarrowOperators *)narrow;
- (void) narrowWithOperators:(NarrowOperators *)narrow thenDisplayId:(long)messageId;
- (BOOL) isNarrowed;
- (NarrowOperators *)currentNarrow;
- (void) clearNarrowWithAnimation:(BOOL)animation;

- (void) reloadCoreData;
@end
