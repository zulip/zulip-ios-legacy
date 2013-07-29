#import <UIKit/UIKit.h>

@interface ErrorViewController : UIViewController

@property (strong, nonatomic) IBOutlet UILabel *errorMessage;

- (IBAction) goBack;

@end
