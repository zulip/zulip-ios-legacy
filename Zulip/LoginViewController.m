#import "LoginViewController.h"
#import "ZulipAppDelegate.h"
#import "ZulipAPIController.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

@synthesize email;
@synthesize password;
@synthesize loginButton;
@synthesize entryFields;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction) login: (id) sender
{
    [[ZulipAPIController sharedInstance] login:email.text password:password.text result:^(bool loggedIn) {
        if (loggedIn) {
            [appDelegate viewStream];
        } else {
            NSLog(@"Failed to login!");
            [self.email resignFirstResponder];
            [self.password resignFirstResponder];
            [appDelegate showErrorScreen:self.view errorMessage:@"Unable to login. Please try again."];
        }
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	// Find the next entry field
	for (UIView *view in self.entryFields) {
		if (view.tag == (textField.tag + 1)) {
			[view becomeFirstResponder];
			break;
		}
	}
	return NO;
}

- (void) animateTextField: (UITextField *) textField up: (BOOL) up
{
    const int movementDistance = 140; // tweak as needed
    const float movementDuration = 0.3f; // tweak as needed

    int movement = (up ? -movementDistance : movementDistance);

    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    self.view.frame = CGRectOffset(self.view.frame, 0, movement);
    [UIView commitAnimations];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.password) {
        [self animateTextField: textField up: YES];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.password) {
        [self animateTextField: textField up: NO];
    }
}

@end
