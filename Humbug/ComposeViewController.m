#import <QuartzCore/QuartzCore.h>
#import "ComposeViewController.h"
#import "HumbugAppDelegate.h"

@interface ComposeViewController ()

@end

@implementation ComposeViewController

@synthesize stream;
@synthesize subject;
@synthesize content;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.content.layer.cornerRadius = 5;
    self.content.clipsToBounds = YES;
    [self.content.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.content.layer setBorderWidth:2.0];
    self.content.delegate = self;

    self.delegate = (HumbugAppDelegate *)[UIApplication sharedApplication].delegate;

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)send
{
    if([self.content isFirstResponder]) {
        [self.content resignFirstResponder];
    };

    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       @"stream", @"type", self.stream, @"stream",
                                       self.subject, @"to", self.content, @"content", nil];
    [self makeJSONMessagePOST:@"send_message" postFields:postFields];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self animateTextView: textView up: YES];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self animateTextView: textView up: NO];
}

- (void) animateTextView: (UITextView *) textView up: (BOOL) up
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

- (NSDictionary *) makeJSONMessagePOST:(NSString *)resource_path
                            postFields:(NSMutableDictionary *)postFields
{
    NSHTTPURLResponse *response = nil;
    NSData *data;

    data = [self.delegate makePOST:&response resource_path:resource_path postFields:postFields useAPICredentials:TRUE];

    if ([response statusCode] != 200) {
        NSLog(@"error sending");
    }

    NSError *e = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData: data
                                                             options: NSJSONReadingMutableContainers
                                                               error: &e];
    if (!jsonDict) {
        NSLog(@"Error parsing JSON: %@", e);
    }

    return jsonDict;
}

@end
