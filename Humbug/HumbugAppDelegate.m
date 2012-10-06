#import "HumbugAppDelegate.h"
#import "KeychainItemWrapper.h"

@implementation HumbugAppDelegate

@synthesize window = _window;
@synthesize tabBarController = _tabBarController;
@synthesize loginViewController = _loginViewController;
@synthesize streamViewController = _streamViewController;
@synthesize errorViewController = _errorViewController;

@synthesize email;
@synthesize apiKey;
@synthesize clientID;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.errorViewController = [[ErrorViewController alloc] init];

    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]
                                         initWithIdentifier:@"HumbugLogin" accessGroup:nil];
    NSString *storedApiKey = [keychainItem objectForKey:kSecValueData];
    NSString *storedEmail = [keychainItem objectForKey:kSecAttrAccount];

    if (storedApiKey == @"") {
        // No credentials stored; we need to log in.
        self.loginViewController = [[LoginViewController alloc] init];
        [self.window setRootViewController:self.loginViewController];
    } else {
        // We have credentials, so try to reuse them. We may still have to log in if they are stale.
        self.apiKey = storedApiKey;
        self.email = storedEmail;

        self.streamViewController = [[StreamViewController alloc] init];
        // Bottom padding so you can see new messages arrive.
        self.streamViewController.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 200.0, 0.0);
        [self.window setRootViewController:self.streamViewController];
    }
    self.clientID = @"";

    [self.window makeKeyAndVisible];

    return YES;
}

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
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
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

- (void)dealloc
{
    [_window release];
    [_tabBarController release];
    [super dealloc];
}


- (NSData *) makePOST:(NSHTTPURLResponse **)response resource_path:(NSString *)resource_path postFields:(NSMutableDictionary *)postFields useAPICredentials:(BOOL)useAPICredentials
{
    NSError *error;
    NSMutableURLRequest *request;

    request = [[[NSMutableURLRequest alloc]
                initWithURL:[NSURL URLWithString:
                             [@"https://app.humbughq.com/api/v1/" stringByAppendingString:resource_path]]
                cachePolicy:NSURLRequestReloadIgnoringCacheData
                timeoutInterval:60] autorelease];
    [request setHTTPMethod:@"POST"];

    if (useAPICredentials) {
        [postFields addEntriesFromDictionary:[NSDictionary
                                              dictionaryWithObjectsAndKeys:self.email, @"email",
                                              self.apiKey, @"api-key",
                                              self.clientID, @"client_id", nil]];
    }

    NSMutableString *postString = [[NSMutableString alloc] init];
    for (id key in postFields) {
        [postString appendFormat:@"%@=%@&", key, [postFields objectForKey:key]];
    }

    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];

    NSString* requestDataLengthString = [[NSString alloc] initWithFormat:@"%d", [postString length]];
    [request setValue:requestDataLengthString forHTTPHeaderField:@"Content-Length"];

    return [NSURLConnection sendSynchronousRequest:request
                                 returningResponse:response error:&error];
}

- (bool) login:(NSString *)username password:(NSString *)password
{
    NSHTTPURLResponse *response;
    NSData *responseData;
    NSString *content;

    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:username,
                                       @"username", password, @"password", nil];
    responseData = [self makePOST:&response resource_path:@"fetch_api_key" postFields:postFields useAPICredentials:FALSE];

    content = [[NSString alloc] initWithBytes:[responseData bytes]
                                       length:[responseData length]
                                     encoding: NSUTF8StringEncoding];

    if ([response statusCode] != 200) {
        return false;
    }
    self.apiKey = content;
    self.email = username;

    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"HumbugLogin" accessGroup:nil];
    [keychainItem setObject:self.apiKey forKey:kSecValueData];
    [keychainItem setObject:self.email forKey:kSecAttrAccount];

    return true;
}

- (void)viewStream
{
    [self.window addSubview:self.streamViewController.view];
}

- (void)showErrorScreen:(UIView *)view errorMessage:(NSString *)errorMessage
{
    [view removeFromSuperview];
    [view addSubview:self.errorViewController.view];
    self.errorViewController.errorMessage.text = errorMessage;
}

@end
