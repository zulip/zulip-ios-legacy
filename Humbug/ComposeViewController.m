#import <QuartzCore/QuartzCore.h>
#import "ComposeViewController.h"
#import "HumbugAppDelegate.h"

@interface ComposeViewController ()

@end

@implementation ComposeViewController

@synthesize recipient;
@synthesize subject;
@synthesize content;
@synthesize type;
@synthesize entryFields;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"view will appear %@", self.type);
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
    self.recipient.delegate = self;
    self.subject.delegate = self;

    if ([self.type isEqualToString:@"stream"]) {
        [self.subject setHidden:NO];
    } else if ([self.type isEqualToString:@"private"]) {
        [self.subject setHidden:YES];
        [self.recipient setPlaceholder:@"one or more people..."];
    }

    self.delegate = (HumbugAppDelegate *)[UIApplication sharedApplication].delegate;

    self.entryFields = [[NSMutableArray alloc] init];
    NSInteger tag = 1;
    UIView *aView;
    while ((aView = [self.view viewWithTag:tag])) {
        if (aView && [[aView class] isSubclassOfClass:[UIResponder class]]) {
            [self.entryFields addObject:aView];
        }
        tag++;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)send
{
    [self.content resignFirstResponder];

    NSMutableDictionary *postFields;
    if ([self.type isEqualToString:@"stream"]) {
        postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"stream", @"type", self.recipient.text, @"to",
                      self.subject.text, @"subject", self.content.text, @"content",
                      nil];
    } else if ([self.type isEqualToString:@"private"]) {
        NSArray* recipient_array = [self.recipient.text componentsSeparatedByString: @","];

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipient_array options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"private", @"type", jsonString, @"to",
                      self.content.text, @"content", nil];
    } else {
        NSLog(@"Invalid message type");
    }
    [self makeJSONMessagePOST:@"send_message" postFields:postFields];
    [self.delegate.navController popViewControllerAnimated:YES];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    //[self animateTextView: textView up: YES];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    //[self animateTextView: textView up: NO];
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

    if ([response statusCode] == 400) {
        NSLog(@"Forbidden: %@", jsonDict);
    }

    return jsonDict;
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

@end
