#import <UIKit/UIKit.h>

@interface LoginViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITextField *email;
@property (strong, nonatomic) IBOutlet UITextField *password;
@property (strong, nonatomic) IBOutlet UIButton *loginButton;

@property (nonatomic, retain) NSMutableArray *entryFields;

- (IBAction) login: (id) sender;
- (IBAction) about: (id)sender;
@end
