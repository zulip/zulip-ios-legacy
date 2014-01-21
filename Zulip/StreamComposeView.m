//
//  StreamComposeView.m
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import "StreamComposeView.h"
#import "ZulipAPIClient.h"
#import "RawMessage.h"
#import "ZulipAPIController.h"
#import "ZUser.h"

#import <Crashlytics/Crashlytics.h>
#import "UIView+Layout.h"

static const CGFloat StreamComposeViewToWidth_Phone = 121.f;
static const CGFloat StreamComposeViewToWidth_Pad = 200.f;


static const CGFloat StreamComposeViewSubjectWidth_Phone = 166.f;
static const CGFloat StreamComposeViewSubjectWidth_Pad = 400;

static const CGFloat StreamComposeViewMessageWidth_Phone = 200.f;
static const CGFloat StreamComposeViewMessageWidth_Pad = 600.f;

static const CGFloat StreamComposeViewInputHeight = 30.f;

@interface StreamComposeView ()<UITextViewDelegate>

@property (strong, nonatomic) UIToolbar *mainBar;
@property (strong, nonatomic) UITextView *messageInput;

@property (strong, nonatomic) UIToolbar *subjectBar;
@property (strong, nonatomic) UITextField *to;
@property (strong, nonatomic) UITextField *subject;
@property (strong, nonatomic) UIBarButtonItem *toItem;
@property (strong, nonatomic) UIBarButtonItem *subjectItem;
@property (strong, nonatomic) UIView *tapHandlerShim;

@end

@implementation StreamComposeView

- (id)init {
    if (self = [super init]) {
        self.mainBar = [[UIToolbar alloc] init];
        [self.mainBar sizeToFit];
        CGSize toolbarSize = self.mainBar.size;

        [self resizeTo:CGSizeMake(toolbarSize.width, toolbarSize.height * 2)];

        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];


        [self.mainBar moveToPoint:CGPointMake(0, toolbarSize.height)];
        self.mainBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        UIBarButtonItem *sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(didTapSendButton)];

        CGFloat messageWidth = (self.isPad ? StreamComposeViewMessageWidth_Pad : StreamComposeViewMessageWidth_Phone);
        self.messageInput = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, messageWidth, StreamComposeViewInputHeight)];
        self.messageInput.layer.cornerRadius = 5.f;
        self.messageInput.layer.borderColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.1f].CGColor;
        self.messageInput.layer.borderWidth = 1.f;
        self.messageInput.delegate = self;
        self.messageInput.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        // iOS 6 has a weird bug where vertical alignment is off in the text
        // view because default font sizes different. This is a hacky workaround.
        if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending) {
            self.messageInput.font = [UIFont systemFontOfSize:14.f];
        }

        UIBarButtonItem *inputItem = [[UIBarButtonItem alloc] initWithCustomView:self.messageInput];


        self.mainBar.items = @[flexibleSpace, inputItem, flexibleSpace, sendButton, fixedSpace];
        [self addSubview:self.mainBar];


        // Subject bar
        CGRect secondBarFrame = CGRectZero;
        secondBarFrame.size = toolbarSize;
        self.subjectBar = [[UIToolbar alloc] initWithFrame:secondBarFrame];
        self.subjectBar.hidden = YES;
        self.subjectBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        CGFloat toWidth = (self.isPad ? StreamComposeViewToWidth_Pad : StreamComposeViewToWidth_Phone);
        self.to = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, toWidth, StreamComposeViewInputHeight)];
        self.to.placeholder = @"Stream";
        self.to.borderStyle = UITextBorderStyleRoundedRect;
        self.to.backgroundColor = [UIColor whiteColor];
        self.to.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.toItem = [[UIBarButtonItem alloc] initWithCustomView:self.to];

        CGFloat subjectWidth = (self.isPad ? StreamComposeViewSubjectWidth_Pad : StreamComposeViewSubjectWidth_Phone);
        self.subject = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, subjectWidth, StreamComposeViewInputHeight)];
        self.subject.placeholder = @"Subject";
        self.subject.borderStyle = UITextBorderStyleRoundedRect;
        self.subject.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.subject.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.subject.backgroundColor = [UIColor whiteColor];
        self.subjectItem = [[UIBarButtonItem alloc] initWithCustomView:self.subject];

        self.subjectBar.items = @[flexibleSpace, self.toItem, fixedSpace, self.subjectItem, flexibleSpace];
        [self addSubview:self.subjectBar];

        // Tapping the compose view focuses the 'to' field, not the message field
        self.tapHandlerShim = [[UIView alloc] initWithFrame:self.bounds];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapComposeView)];
        [self.tapHandlerShim addGestureRecognizer:tap];
        [self addSubview:self.tapHandlerShim];

    }
    return self;
}

- (void)showComposeViewForMessage:(RawMessage *)message {
    if ([message.type isEqualToString:@"private"]) {
        NSMutableArray *emails = [[message.pm_recipients.allObjects valueForKey:@"email"] mutableCopy];
        [emails removeObject:[[ZulipAPIController sharedInstance] email]];
        NSString *recipientString = [emails componentsJoinedByString:@", "];

        self.isPrivate = YES;
        self.recipient = recipientString;
    } else {
        self.isPrivate = NO;
        self.recipient = message.stream_recipient;
        self.subject.text = message.subject;
    }

    [self.messageInput becomeFirstResponder];
}

- (void)showComposeViewForUser:(ZUser *)user {
    self.isPrivate = YES;
    self.recipient = user.email;
    [self.messageInput becomeFirstResponder];
}

- (void)showSubjectBar {
    self.subjectBar.hidden = NO;
    self.tapHandlerShim.hidden = YES;
}

- (void)hideSubjectBar {
    self.subjectBar.hidden = YES;
    self.tapHandlerShim.hidden = NO;
}

- (CGFloat)visibleHeight {
    if (self.subjectBar.hidden) {
        return self.mainBar.height;
    } else {
        return self.height;
    }
}

- (NSString *)recipient {
    return self.to.text;
}

- (void)setRecipient:(NSString *)recipient {
    self.to.text = recipient;
}

- (void)setIsPrivate:(BOOL)isPrivate {
    _isPrivate = isPrivate;

    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];


    if (isPrivate) {
        self.to.placeholder = @"One or more people...";
        [self.to resizeTo:self.messageInput.size];
        self.subjectBar.items = @[flexibleSpace, self.toItem, flexibleSpace];
    } else {
        self.to.placeholder = @"Stream";
        CGFloat toWidth = (self.isPad ? StreamComposeViewToWidth_Pad : StreamComposeViewToWidth_Phone);
        [self.to resizeTo:CGSizeMake(toWidth, self.messageInput.height)];
        self.subjectBar.items = @[flexibleSpace, self.toItem, fixedSpace, self.subjectItem, flexibleSpace];
    }
}

- (BOOL)isFirstResponder {
    return self.messageInput.isFirstResponder || self.to.isFirstResponder || self.subject.isFirstResponder;
}

- (BOOL)resignFirstResponder {
    [super resignFirstResponder];
    [self.messageInput resignFirstResponder];
    [self.to resignFirstResponder];
    [self.subject resignFirstResponder];

    return YES;
}

#pragma mark - Event handlers
- (void)didTapSendButton {
    NSDictionary *postFields;
    if (self.isPrivate) {
        NSArray* recipientArray = [self.to.text componentsSeparatedByString: @","];

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipientArray options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        postFields = @{ @"type": @"private",
                        @"to": jsonString,
                        @"content": self.messageInput.text };
    } else {
        postFields = @{ @"type": @"stream",
                        @"to": self.to.text,
                        @"subject": self.subject.text,
                        @"content": self.messageInput.text };
    }

    [[ZulipAPIClient sharedClient] postPath:@"messages" parameters:postFields success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        CLS_LOG(@"Error posting message: %@", [error localizedDescription]);
    }];

    self.messageInput.text = @"";
}

- (void)didTapComposeView {
    [self.to becomeFirstResponder];
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView
{
    CGSize newSize = [textView sizeThatFits:CGSizeMake(textView.width, MAXFLOAT)];
    CGRect newFrame = textView.frame;
    newFrame.size = CGSizeMake(fmaxf(newSize.width, textView.width), newSize.height);

    CGFloat heightDifference = newSize.height - textView.frame.size.height;

    [UIView animateWithDuration:0.1f animations:^{
        textView.frame = newFrame;
        [self.mainBar resizeTo:CGSizeMake(self.mainBar.width, self.mainBar.height + heightDifference)];

        [self resizeTo:CGSizeMake(self.width, self.height + heightDifference)];
        [self moveBy:CGPointMake(0, -heightDifference)];
    }];
}

#pragma mark - Private
- (BOOL)isPad {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

@end
