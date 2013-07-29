#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "FirstViewController.h"
#import "StreamViewController.h"
#import "ErrorViewController.h"
#import "AFHTTPRequestOperation.h"

@interface HumbugAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate>

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

@property (nonatomic, retain) NSString *apiKey;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *clientID;
@property (nonatomic, retain) NSString *apiURL;

- (void) login:(NSString *)email password:(NSString *)password result:(void (^) (bool success))result;
- (void) viewStream;
- (void) showErrorScreen:(UIView *)view errorMessage:(NSString *)errorMessage;
- (void) dismissErrorScreen;

@end
