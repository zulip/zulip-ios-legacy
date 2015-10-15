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
#import "ComposeAutocompleteView.h"
#import "RenderedMarkdownMunger.h"

#import "UIView+Layout.h"

static const CGFloat StreamComposeViewToWidth_Phone = 121.f;
static const CGFloat StreamComposeViewToWidth_Pad = 200.f;

static const CGFloat StreamComposeViewSubjectWidth_Phone = 166.f;
static const CGFloat StreamComposeViewSubjectWidth_Pad = 525;

static const CGFloat StreamComposeViewMessageWidth_Phone = 245.f;
static const CGFloat StreamComposeViewMessageWidth_Pad = 670.f;

static const CGFloat StreamComposeViewInputHeight = 30.f;

@interface StreamComposeView ()<UITextViewDelegate>

@property (strong, nonatomic) UIToolbar *mainBar;
@property (strong, nonatomic) UITextView *messageInput;
@property (strong, nonatomic) NSString *recipient;

@property (strong, nonatomic) UIToolbar *subjectBar;
@property (strong, nonatomic) UITextField *to;
@property (strong, nonatomic) UITextField *subject;
@property (strong, nonatomic) UIBarButtonItem *toItem;
@property (strong, nonatomic) UIBarButtonItem *subjectItem;
@property (strong, nonatomic) UIBarButtonItem *sendButton;
@property (strong, nonatomic) UIView *tapHandlerShim;

@property (strong, nonatomic) NSMutableSet *foundEmoji;

@property (assign, nonatomic) BOOL isCurrentlyPrivate;

@end

@implementation StreamComposeView

- (id)initWithAutocompleteView:(ComposeAutocompleteView *)autocompleteView {
    if (self = [super init]) {
        [self commonInit];
        self.autocompleteView = autocompleteView;
        self.autocompleteView.messageBody = self.messageInput;
    }
    return self;
}

- (id)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    [self renderMainBar];
    [self renderRecipientBar];

    self.foundEmoji = [[NSMutableSet alloc] init];

    // Tapping the compose view focuses the 'to' field, not the message field
    self.tapHandlerShim = [[UIView alloc] initWithFrame:self.bounds];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapComposeView)];
    [self.tapHandlerShim addGestureRecognizer:tap];
    [self addSubview:self.tapHandlerShim];

    [[NSNotificationCenter defaultCenter] addObserverForName:kLogoutNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      self.to.text = @"";
                                                      self.subject.text = @"";
                                                      self.messageInput.text = @"";
                                                  }];
}

- (void)showComposeViewForMessage:(RawMessage *)message {
    if ([self.delegate respondsToSelector:@selector(willShowComposeView)]) {
        [self.delegate willShowComposeView];
    }

    if ([message.type isEqualToString:@"private"]) {
        NSMutableArray *emails = [[message.pm_recipients.allObjects valueForKey:@"email"] mutableCopy];
        [emails removeObject:[[ZulipAPIController sharedInstance] email]];
        NSString *recipientString = [emails componentsJoinedByString:@", "];

        [self showPrivateCompose];
        self.recipient = recipientString;
        self.defaultRecipient = recipientString;
    } else {
        [self showPublicCompose];
        self.recipient = message.stream_recipient;
        self.defaultRecipient = message.stream_recipient;
        self.subject.text = message.subject;
    }

    [self focusNextInput];
}

- (void)showComposeViewForUser:(ZUser *)user {
    if ([self.delegate respondsToSelector:@selector(willShowComposeView)]) {
        [self.delegate willShowComposeView];
    }

    [self showPrivateCompose];
    self.recipient = user.email;
    [self focusNextInput];
}

- (void)showComposeView {
    if (self.isPrivate) {
        [self showPrivateCompose];
    } else {
        [self showPublicCompose];
    }

    [self focusNextInput];
}

- (void)showOneTimePrivateCompose
{
    self.defaultRecipient = @"";
    [self showPrivateCompose];
    [self focusNextInput];
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
    self.isCurrentlyPrivate = isPrivate;

    if (isPrivate) {
        [self showPrivateCompose];
    } else {
        [self showPublicCompose];
    }
}

- (void)showPrivateCompose {
    self.isCurrentlyPrivate = YES;

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.to.placeholder = @"One or more people...";
    self.to.text = self.defaultRecipient;

    // PM bar goes from left edge of input field to right edge of send button
    // We can't get a UIView from a bar buttom item directly, but we know the index
    // (see https://stackoverflow.com/questions/2994354/figure-out-uibarbuttonitem-frame-in-window)
    // So we get the correctly indexed view in the list of subviews
    float rowPadding = 4.0f;
    UIView *sendView = (UIView *)[self.mainBar.subviews objectAtIndex:3];
    float width = ((float)sendView.frame.origin.x + (float)sendView.frame.size.width) - (float)self.messageInput.frame.origin.x + rowPadding;
    CGSize toSize = CGSizeMake(width, self.messageInput.frame.size.height);

    [self.to resizeTo:toSize];
    self.subjectBar.items = @[flexibleSpace, self.toItem, flexibleSpace];

    [self.autocompleteView resetRegisteredTextFields];
    [self.autocompleteView registerTextField:self.to forType:ComposeAutocompleteTypeUser];
}

- (void)showPublicCompose {
    self.isCurrentlyPrivate = NO;

    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.to.placeholder = @"Stream";
    self.to.text = self.defaultRecipient;

    CGFloat toWidth = (self.isPad ? StreamComposeViewToWidth_Pad : StreamComposeViewToWidth_Phone);
    [self.to resizeTo:CGSizeMake(toWidth, self.messageInput.height)];
    self.subjectBar.items = @[flexibleSpace, self.toItem, fixedSpace, self.subjectItem, flexibleSpace];

    [self.autocompleteView resetRegisteredTextFields];
    [self.autocompleteView registerTextField:self.to forType:ComposeAutocompleteTypeStream];
    [self.autocompleteView registerTextField:self.subject forType:ComposeAutocompleteTypeTopic];
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

- (BOOL)canSend
{
    if ([self.to.text isEqualToString:@""]) {
        return NO;
    }

    return YES;
}

#pragma mark - Event handlers
- (void)didTapSendButton {
    if (![self canSend]) {
        return;
    }

    NSString *subject = self.subject.text;
    if (!self.isCurrentlyPrivate && [subject isEqualToString:@""]) {
        subject = @"(no topic)";
    }

    NSMutableString *msg = [self.messageInput.text mutableCopy];
    if (self.foundEmoji.count > 0) {
        for (NSDictionary *foundEmoji in self.foundEmoji) {
            NSString *replacement = foundEmoji[@"shortname"];
            [msg replaceOccurrencesOfString:foundEmoji[@"unicode"] withString:replacement options:0 range:NSMakeRange(0, msg.length)];
        }
        self.foundEmoji = [[NSMutableSet alloc] init];
    }

    NSDictionary *postFields;
    if (self.isCurrentlyPrivate) {
        NSArray* recipientArray = [self.to.text componentsSeparatedByString: @","];

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipientArray options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        postFields = @{ @"type": @"private",
                        @"to": jsonString,
                        @"content": msg };
    } else {
        postFields = @{ @"type": @"stream",
                        @"to": self.to.text,
                        @"subject": subject,
                        @"content": msg };
    }

    [[ZulipAPIClient sharedClient] postPath:@"messages" parameters:postFields success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error posting message: %@", [error localizedDescription]);
    }];

    self.messageInput.text = @"";
    [self textViewDidChange:self.messageInput];
}

- (void)focusNextInput
{
    // Focuses input view that should get focus when opening the compose box
    UIResponder *toFocus = nil;
    if ([[self.to text] isEqualToString:@""]) {
        toFocus = self.to;
    } else {
        if (!self.isCurrentlyPrivate && [[self.subject text] isEqualToString:@""]) {
            toFocus = self.subject;
        } else {
            toFocus = self.messageInput;
        }
    }
    [toFocus becomeFirstResponder];
}

- (void)didTapComposeView {
    [self showComposeView];
    if ([self.delegate respondsToSelector:@selector(willShowComposeView)]) {
        [self.delegate willShowComposeView];
    }

    [self.to becomeFirstResponder];
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView
{
    CGSize newSize = [textView sizeThatFits:CGSizeMake(textView.width, MAXFLOAT)];
    CGRect newFrame = textView.frame;
    newFrame.size = CGSizeMake(fmaxf((float)newSize.width, (float)textView.width), newSize.height);

    CGFloat heightDifference = newSize.height - textView.frame.size.height;

    // Immediately resize the mainBar and compose view to the new size, but animate
    // the compose box growing and the overall compose area growing up
    [self.mainBar resizeTo:CGSizeMake(self.mainBar.width, self.mainBar.height + heightDifference)];
    [self resizeTo:CGSizeMake(self.width, self.height + heightDifference)];

    [UIView animateWithDuration:0.1f animations:^{
        [self moveBy:CGPointMake(0, -heightDifference)];
        textView.frame = newFrame;
    }];

    // Replace UTF8 emoji with :shortname: if found in the last 4 (wide) or 2 chars
    NSArray *emojiUnicodeLengths = @[@(4), @(2)];
    for (NSNumber *emojiLength in emojiUnicodeLengths) {
        NSUInteger length = [emojiLength unsignedIntegerValue];
        if (textView.text.length > length - 1) {
            NSString *potentialEmoji = [textView.text substringFromIndex:(textView.text.length - length)];
            NSString *shortname = [RenderedMarkdownMunger emojiShortNameFromUnicode:potentialEmoji];
            if (shortname) {
                [self.foundEmoji addObject:@{@"shortname": [NSString stringWithFormat:@" :%@: ", shortname],
                                             @"unicode": potentialEmoji}];
            }
        }
    }
}

#pragma mark - Private
- (BOOL)isPad {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (void)renderMainBar {
    self.mainBar = [[UIToolbar alloc] init];
    [self.mainBar sizeToFit];
    CGSize toolbarSize = self.mainBar.size;

    [self resizeTo:CGSizeMake(toolbarSize.width, toolbarSize.height * 2)];

    [self.mainBar moveToPoint:CGPointMake(0, toolbarSize.height)];
    self.mainBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    UIBarButtonItem *fixedNegativeSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixedNegativeSpace.width = -4.0f;

    self.sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(didTapSendButton)];

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

    // NOTE: If you change the order or number of items in the mainBar, also update
    // showPrivateCompose:
    self.mainBar.items = @[fixedNegativeSpace, inputItem, flexibleSpace, self.sendButton, fixedSpace];
    [self addSubview:self.mainBar];
}

- (void)renderRecipientBar {
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

    CGRect secondBarFrame = CGRectZero;
    secondBarFrame.size = self.mainBar.size;
    self.subjectBar = [[UIToolbar alloc] initWithFrame:secondBarFrame];
    self.subjectBar.hidden = YES;
    self.subjectBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    CGFloat toWidth = (self.isPad ? StreamComposeViewToWidth_Pad : StreamComposeViewToWidth_Phone);
    self.to = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, toWidth, StreamComposeViewInputHeight)];
    self.to.placeholder = @"Stream";
    self.to.borderStyle = UITextBorderStyleRoundedRect;
    self.to.font = [UIFont systemFontOfSize:14.f];
    self.to.backgroundColor = [UIColor whiteColor];
    self.to.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.toItem = [[UIBarButtonItem alloc] initWithCustomView:self.to];

    CGFloat subjectWidth = (self.isPad ? StreamComposeViewSubjectWidth_Pad : StreamComposeViewSubjectWidth_Phone);
    self.subject = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, subjectWidth, StreamComposeViewInputHeight)];
    self.subject.placeholder = @"Topic";
    self.subject.borderStyle = UITextBorderStyleRoundedRect;
    self.subject.font = [UIFont systemFontOfSize:14.f];
    self.subject.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.subject.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.subject.backgroundColor = [UIColor whiteColor];
    self.subjectItem = [[UIBarButtonItem alloc] initWithCustomView:self.subject];

    self.subjectBar.items = @[flexibleSpace, self.toItem, fixedSpace, self.subjectItem, flexibleSpace];
    [self addSubview:self.subjectBar];
}

@end
