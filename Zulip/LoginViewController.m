#import "LoginViewController.h"
#import "ZulipAppDelegate.h"
#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"
#import "GoogleOAuthManager.h"

#import "BrowserViewController.h"
#import "UIView+Layout.h"
#import "MBProgressHUD.h"

@interface LoginViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) ZulipAppDelegate *appDelegate;
@property (strong, nonatomic) GoogleOAuthManager *googleManager;
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
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Event handlers
- (IBAction)didTapGoogleButton:(id)sender {
    self.googleManager = [[GoogleOAuthManager alloc] init];
    UIViewController *loginController = [self.googleManager showAuthScreenWithSuccess:^(NSDictionary *result) {
        [self.navigationController popViewControllerAnimated:NO];
        [self loginWithUsername:@"google-oauth2-token" password:result[@"id_token"]];
    } failure:^(NSError *error) {
        [self.navigationController popViewControllerAnimated:YES];
        [self.appDelegate showErrorScreen:@"Unable to login with Google. Please try again."];
    }];

    [self.email resignFirstResponder];
    [self.password resignFirstResponder];
    [self.navigationController pushViewController:loginController animated:YES];
}

- (void)loginWithUsername:(NSString *)email password:(NSString *)password {
    [[ZulipAPIController sharedInstance] logout];
    [[ZulipAPIController sharedInstance] login:email password:password result:^(bool loggedIn) {
        if (loggedIn) {
            [self.appDelegate dismissLoginScreen];
        } else {
            NSLog(@"Failed to login!");
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
