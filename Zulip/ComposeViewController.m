#import <QuartzCore/QuartzCore.h>
#import "ComposeViewController.h"
#import "ZulipAppDelegate.h"
#import "ZulipAPIClient.h"
#import "ZulipAPIController.h"

@interface ComposeViewController ()

@property (nonatomic, retain) RawMessage *replyTo;

@end

@implementation ComposeViewController

- (id)initWithReplyTo:(RawMessage *)message
{
    self = [super initWithNibName:@"ComposeViewController" bundle:nil];
    if (self) {
        self.replyTo = message;
    }

    return self;
}

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
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.content.layer.cornerRadius = 5;
    self.content.clipsToBounds = YES;
    [self.content.layer setBorderColor:[[[UIColor grayColor] colorWithAlphaComponent:0.5] CGColor]];
    [self.content.layer setBorderWidth:2.0];

    // On iOS 7, don't extend our content under the toolbar
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        self.edgesForExtendedLayout = UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
    }

    if ([self.type isEqualToString:@"stream"]) {
        self.subject.hidden = NO;

        self.recipient.hidden = NO;
        self.recipient.text = self.replyTo.stream_recipient;

        self.subject.text = self.replyTo.subject;

        self.privateRecipient.hidden = YES;
    } else if ([self.type isEqualToString:@"private"]) {
        self.subject.hidden = YES;

        self.recipient.hidden = YES;

        self.privateRecipient.hidden = NO;

        NSSet *recipients = self.replyTo.pm_recipients;
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (ZUser *recipient in recipients) {
            if (![recipient.email isEqualToString:[[ZulipAPIController sharedInstance] email]]) {
                [recipient_array addObject:recipient.email];
            }
        }
        self.privateRecipient.text = [recipient_array componentsJoinedByString:@", "];
    }


    self.delegate = (ZulipAppDelegate *)[UIApplication sharedApplication].delegate;

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
        NSArray* recipient_array = [self.privateRecipient.text componentsSeparatedByString: @","];

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipient_array options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"private", @"type", jsonString, @"to",
                      self.content.text, @"content", nil];
    } else {
        NSLog(@"Invalid message type");
    }

    [[ZulipAPIClient sharedClient] postPath:@"messages" parameters:postFields success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error posting message: %@", [error localizedDescription]);
    }];

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
