#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "StreamViewController.h"
#import "ErrorViewController.h"
#import "AFHTTPRequestOperation.h"

@interface ZulipAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate>

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UITabBarController *tabBarController;
@property (nonatomic, retain) IBOutlet UINavigationController *navController;
@property (nonatomic, retain) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, retain) IBOutlet StreamViewController *streamViewController;
@property (nonatomic, retain) IBOutlet ErrorViewController *errorViewController;

// Core Data bits
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void) viewStream;
- (void) showErrorScreen:(NSString *)errorMessage;
- (void) dismissErrorScreen;

@end
