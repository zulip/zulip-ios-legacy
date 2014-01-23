#import "LoginViewController.h"
#import "ZulipAppDelegate.h"
#import "ZulipAPIController.h"

#import "UIView+Layout.h"

#import <Crashlytics/Crashlytics.h>

@interface LoginViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@end

@implementation LoginViewController

@synthesize email;
@synthesize password;
@synthesize loginButton;
@synthesize entryFields;

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
    appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];

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

- (IBAction) login: (id) sender
{
    NSString *trimmedEmail = [email.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [[ZulipAPIController sharedInstance] logout];
    [[ZulipAPIController sharedInstance] login:trimmedEmail password:password.text result:^(bool loggedIn) {
        if (loggedIn) {
            [appDelegate dismissLoginScreen];
        } else {
            CLS_LOG(@"Failed to login!");
            [self.email resignFirstResponder];
            [self.password resignFirstResponder];
            [appDelegate showErrorScreen:@"Unable to login. Please try again."];
        }
    }];
}

- (IBAction) about:(id)sender
{
    [appDelegate showAboutScreen];
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
