#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "HomeViewController.h"
#import "ErrorViewController.h"
#import "AFHTTPRequestOperation.h"
#import "JASidePanelController.h"

@interface ZulipAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate>

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UITabBarController *tabBarController;
@property (nonatomic, retain) UINavigationController *navController;
@property (nonatomic, retain) JASidePanelController *sidePanelController;
@property (nonatomic, retain) LoginViewController *loginViewController;
@property (nonatomic, retain) HomeViewController *homeViewController;
@property (nonatomic, retain) ErrorViewController *errorViewController;

// Core Data bits
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void) showErrorScreen:(NSString *)errorMessage;
- (void) dismissErrorScreen;
- (void) dismissLoginScreen;

// Narrowing
- (void) narrow:(NSPredicate *)predicate;
- (BOOL) isNarrowed;
- (void) clearNarrowWithAnimation:(BOOL)animation;

- (void) reloadCoreData;
@end
