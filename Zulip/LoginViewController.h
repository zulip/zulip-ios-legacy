#import <UIKit/UIKit.h>

@class ZulipAppDelegate;

@interface LoginViewController : UIViewController
{
    IBOutlet UITextField *email;
    IBOutlet UITextField *password;
    IBOutlet UIButton *loginButton;
    ZulipAppDelegate *appDelegate;
}

@property (strong, nonatomic) IBOutlet UITextField *email;
@property (strong, nonatomic) IBOutlet UITextField *password;
@property (strong, nonatomic) IBOutlet UIButton *loginButton;

@property (nonatomic, retain) NSMutableArray *entryFields;

- (IBAction) login: (id) sender;
- (IBAction) about: (id)sender;
@end
