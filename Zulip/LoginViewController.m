#import "LoginViewController.h"
#import "ZulipAppDelegate.h"
#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"

#import "BrowserViewController.h"
#import "UIView+Layout.h"
#import <Crashlytics/Crashlytics.h>
#import <Crashlytics/Crashlytics.h>
#import "MBProgressHUD.h"

static NSString * const GoogleOAuthURLRoot = @"https://accounts.google.com/o/oauth2";
static NSString * const GoogleOAuthClientId = @"835904834568-gs3ncqe5d182tsh2brcv37hfc4vvdk07.apps.googleusercontent.com";
static NSString * const GoogleOAuthClientSecret = @"RVLTUT3UQrjJsYGjl-pha9bb";
static NSString * const GoogleOAuthAudience = @"835904834568-77mtr5mtmpgspj9b051del9i9r5t4g4n.apps.googleusercontent.com";
static NSString * const GoogleOAuthRedirectURI = @"http://localhost";
static NSString * const GoogleOAuthScope = @"email";

@interface LoginViewController ()<BrowserViewDelegate>
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) ZulipAppDelegate *appDelegate;
@end

@implementation LoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:YES animated:YES];

    self.password.secureTextEntry = YES;
    self.appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];

    self.entryFields = [[NSMutableArray alloc] init];
    NSInteger tag = 1;
    UIView *aView;
    while ((aView = [self.view viewWithTag:tag])) {
        if (aView && [[aView class] isSubclassOfClass:[UIResponder class]]) {
            [self.entryFields addObject:aView];
        }
        tag++;
    }

    // Focus on email field.
    [self.email becomeFirstResponder];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    self.scrollView.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Event handlers
- (IBAction)didTapGoogleButton:(id)sender {
    NSString *urlString = [NSString stringWithFormat:@"%@/auth?scope=%@&redirect_uri=%@&response_type=code&client_id=%@", GoogleOAuthURLRoot, GoogleOAuthScope, GoogleOAuthRedirectURI, GoogleOAuthClientId];
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    BrowserViewController *browser = [[BrowserViewController alloc] initWithUrls:url];
    browser.delegate = self;
    [self.navigationController pushViewController:browser animated:YES];
}

- (BOOL)openURL:(NSURL *)url {
    if ([url.host isEqualToString:@"localhost"]) {
        NSArray *queryPairs = [url.query componentsSeparatedByString:@"&"];
        NSMutableDictionary *queryArgs = [NSMutableDictionary new];
        for (NSString *pair in queryPairs) {
            NSArray *components = [pair componentsSeparatedByString:@"="];
            queryArgs[components[0]] = components[1];
        }

        if (queryArgs[@"code"]) {
            [self fetchTokenForCode:queryArgs[@"code"]];
        } else {
            [self.navigationController popViewControllerAnimated:YES];
            [self.appDelegate showErrorScreen:@"Unable to login with Google. Please try again."];
        }
        return NO;
    }
    return YES;
}

- (void)fetchTokenForCode:(NSString *)code {
    [self.navigationController popViewControllerAnimated:YES];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    NSDictionary *params = @{@"code": code,
                             @"client_id": GoogleOAuthClientId,
                             @"client_secret": GoogleOAuthClientSecret,
                             @"redirect_uri": GoogleOAuthRedirectURI,
                             @"grant_type": @"authorization_code",
                             @"audience": GoogleOAuthAudience,
                             @"aud": GoogleOAuthAudience};
    AFHTTPClient *client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:GoogleOAuthURLRoot]];
    [client postPath:@"token" parameters:params success:^(AFHTTPRequestOperation *operation, NSData *responseObject) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        NSError *jsonError;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:&jsonError];
        if (!jsonError && result[@"id_token"]) {
            [self loginWithUsername:@"google-oauth2-token" password:result[@"id_token"]];
        } else {
            [self.appDelegate showErrorScreen:@"Unable to login with Google. Please try again."];
        }

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        [self.appDelegate showErrorScreen:@"Unable to login with Google. Please try again."];
    }];
}

- (void)loginWithUsername:(NSString *)email password:(NSString *)password {
    [[ZulipAPIController sharedInstance] logout];
    [[ZulipAPIController sharedInstance] login:email password:password result:^(bool loggedIn) {
        if (loggedIn) {
            [self.appDelegate dismissLoginScreen];
        } else {
            CLS_LOG(@"Failed to login!");
            [self.email resignFirstResponder];
            [self.password resignFirstResponder];
            [self.appDelegate showErrorScreen:@"Unable to login. Please try again."];
        }
    }];
}

- (IBAction) login: (id) sender {
    NSString *trimmedEmail = [self.email.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self loginWithUsername:trimmedEmail password:self.password.text];
}

- (IBAction) about:(id)sender
{
    [self.appDelegate showAboutScreen];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	// Find the next entry field
	for (UIView *view in self.entryFields) {
		if (view.tag == (textField.tag + 1)) {
			[view becomeFirstResponder];
			break;
		}
	}

    if (textField == self.password) {
        [textField resignFirstResponder];
        [self login:nil];
    }

	return NO;
}

#pragma mark - Keyboard functions
- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameForTextField = [self.view convertRect:keyboardFrame fromView:nil];

    NSLog(@"%f, %f", keyboardFrameForTextField.size.height, self.view.height);
    self.scrollView.contentSize = CGSizeMake(self.view.width, self.view.height);
    [self.scrollView resizeTo:CGSizeMake(self.view.width, self.view.height - keyboardFrameForTextField.size.height)];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self.scrollView resizeTo:self.view.size];
}

@end
