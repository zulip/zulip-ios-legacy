#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "FirstViewController.h"
#import "StreamViewController.h"
#import "ErrorViewController.h"

@interface HumbugAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate>

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UITabBarController *tabBarController;
@property (nonatomic, retain) IBOutlet UINavigationController *navController;
@property (nonatomic, retain) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, retain) IBOutlet StreamViewController *streamViewController;
@property (nonatomic, retain) IBOutlet ErrorViewController *errorViewController;

@property (nonatomic, retain) NSString *apiKey;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *clientID;

- (NSData *) makePOST:(NSHTTPURLResponse **)response resource_path:(NSString *)resource_path
           postFields:(NSMutableDictionary *)postFields useAPICredentials:(BOOL)useAPICredentials;
- (bool) login:(NSString *)email password:(NSString *)password;
- (void) viewStream;
- (void) showErrorScreen:(UIView *)view errorMessage:(NSString *)errorMessage;

@end
