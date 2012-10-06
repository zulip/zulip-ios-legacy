#import <UIKit/UIKit.h>

@class HumbugAppDelegate;

@interface LoginViewController : UIViewController
{
    IBOutlet UITextField *email;
    IBOutlet UITextField *password;
    IBOutlet UIButton *loginButton;
    HumbugAppDelegate *appDelegate;
}

@property (strong, nonatomic) IBOutlet UITextField *email;
@property (strong, nonatomic) IBOutlet UITextField *password;
@property (strong, nonatomic) IBOutlet UIButton *loginButton;

- (IBAction) login: (id) sender;

@end
