#import <UIKit/UIKit.h>

@interface ErrorViewController : UIViewController

@property (strong, nonatomic) IBOutlet UILabel *errorMessage;

@property (nonatomic, retain) UIView *whereWeCameFrom;

- (IBAction) goBack;

@end
