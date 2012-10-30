#import "LoginViewController.h"
#import "HumbugAppDelegate.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

@synthesize email;
@synthesize password;
@synthesize loginButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.password.secureTextEntry = TRUE;
    appDelegate = (HumbugAppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction) login: (id) sender
{
    bool loggedIn = [appDelegate login:email.text password:password.text];
    if (loggedIn) {
        [appDelegate viewStream];
    } else {
        NSLog(@"Failed to login!");
        [appDelegate showErrorScreen:self.view errorMessage:@"Unable to login"];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
