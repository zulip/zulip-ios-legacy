#import "MessageCell.h"
#import "ZulipAppDelegate.h"
#import "UIImageView+AFNetworking.h"
#import "ZUser.h"
#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"

#import "UIView+Layout.h"
#import <FontAwesomeKit/FAKFontAwesome.h>

@interface MessageCell ()

@property (nonatomic, retain) NSDateFormatter *dateFormatter;
@property (weak, nonatomic) IBOutlet UIButton *starButton;

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIView *senderView;
@property (weak, nonatomic) IBOutlet UIView *bodyView;

@property (assign, nonatomic) CGFloat topOffset;

@end

@implementation MessageCell

+ (CGFloat)heightForCellWithMessage:(RawMessage *)message
                    previousMessage:(RawMessage *)previousMessage
{
    static dispatch_once_t onceToken;
    static DTAttributedTextContentView *dummyContentViewPortrait;
    static DTAttributedTextContentView *dummyContentViewLandscape;
    static CGFloat portraitContentWidth;
    static CGFloat landscapeContentWidth;
    dispatch_once(&onceToken, ^{
        //The number of pixels to the left and right of the message content box.
        CGFloat padding = 55.0 + 8.0;

        portraitContentWidth = [[UIScreen mainScreen] bounds].size.width - padding;
        dummyContentViewPortrait = [[DTAttributedTextContentView alloc] initWithFrame:CGRectMake(0, 0, portraitContentWidth, 1)];
        landscapeContentWidth = [[UIScreen mainScreen] bounds].size.height - padding;
        dummyContentViewLandscape = [[DTAttributedTextContentView alloc] initWithFrame:CGRectMake(0, 0, landscapeContentWidth, 1)];
    });

    DTAttributedTextContentView *currentDummyContentView;
    CGFloat contentWidth;

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (orientation == UIInterfaceOrientationPortrait){
        currentDummyContentView = dummyContentViewPortrait;
        contentWidth = portraitContentWidth;
    } else {
        currentDummyContentView = dummyContentViewLandscape;
        contentWidth = landscapeContentWidth;
    }

    currentDummyContentView.attributedString = message.attributedString;
    CGFloat textHeight = [currentDummyContentView suggestedFrameSizeToFitEntireStringConstraintedToWidth:contentWidth].height;

    CGFloat bodyHeight = 60;

    BOOL isSameTopic = [message isSameTopicAsMessage:previousMessage];
    BOOL isSameSender = [message isSameSenderAsMessage:previousMessage];

    if (isSameTopic && isSameSender) {
        return textHeight + 26; // Room for the timestamp + some bottom padding
    }

    CGFloat headerHeight = isSameTopic ? 0 : 21.0;
    return fmaxf((float)(bodyHeight + headerHeight), (float)(textHeight + 26.0 + headerHeight));
}

+ (UIColor *)defaultStreamColor {
    return [UIColor colorWithRed:187.0f/255
                           green:187.0f/255
                            blue:187.0f/255
                           alpha:1];
}

+ (NSString *)reuseIdentifier {
    return @"CustomCellIdentifier";
}

- (void)awakeFromNib
{
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [self.dateFormatter setDateFormat:@"HH:mm"];

    CGSize starSize = CGSizeMake(15, 15);
    FAKFontAwesome *emptyStar = [FAKFontAwesome starOIconWithSize:starSize.height];
    [emptyStar addAttribute:NSForegroundColorAttributeName value:[UIColor
                                                                 lightGrayColor]];
    FAKFontAwesome *fullStar = [FAKFontAwesome starIconWithSize:starSize.height];
    [fullStar addAttribute:NSForegroundColorAttributeName value:[UIColor
                                                                  lightGrayColor]];

    [self.starButton setImage:[emptyStar imageWithSize:starSize]
                     forState:UIControlStateNormal];
    [self.starButton setImage:[fullStar imageWithSize:starSize]
                     forState:UIControlStateSelected];

    self.topOffset = self.bodyView.top;

    [self prepareForReuse];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.senderView.hidden = NO;
    self.headerView.hidden = NO;
}

- (void)setMessage:(RawMessage *)message
{
    self.type = message.type;

    if ([self.type isEqualToString:@"stream"]) {
        self.header.text = [NSString stringWithFormat:@"%@ > %@",
                            message.stream_recipient,
                            message.subject];
        self.recipient = message.stream_recipient;
    } else if ([self.type isEqualToString:@"private"]) {
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];

        for (ZUser *recipient in message.pm_recipients) {
            if (![recipient.email isEqualToString:[[ZulipAPIController sharedInstance] email]]) {
                [recipient_array addObject:recipient.full_name];
            }
        }
        self.recipient = [recipient_array componentsJoinedByString:@", "];
        if ([recipient_array count]) {
            self.header.text = [@"You and " stringByAppendingString:self.recipient];
        } else {
            self.header.text = [NSString stringWithFormat:@"You and %@", [[ZulipAPIController sharedInstance] fullName]];
        }
    }

    self.sender.text = message.sender.full_name;

    // Asynchronously load gravatar if needed
    [self.gravatar setImageWithURL:[NSURL URLWithString:message.avatar_url]];

    // Mask to get rounded corners
    // TODO apparently this can be slow during animations?
    // If it makes scrolling slow, switch over to manually
    // creating the UIImage by applying a mask with Core Graphics
    // instead of using the view's layer.
    CALayer *layer = self.gravatar.layer;
    [layer setMasksToBounds:YES];
    [layer setCornerRadius:21.0f];

    self.timestamp.text = [self.dateFormatter stringFromDate:message.timestamp];

    // When a message is on the screen, mark it as read
    message.read = YES;

    _message = message;
    self.attributedTextView.attributedString = message.attributedString;
    self.attributedTextView.delegate = self;

    self.starButton.selected = message.starred;
}

- (void)willBeDisplayedWithPreviousMessage:(RawMessage *)previousMessage
{
    if ([self.type isEqualToString:@"stream"]) {
        self.headerBar.backgroundColor = [[ZulipAPIController sharedInstance] streamColor:self.recipient withDefault:[MessageCell defaultStreamColor]];
        self.backgroundColor = [UIColor clearColor];
        self.header.textColor = [UIColor blackColor];
    } else {
        // For non-stream messages, color cell background pale yellow (#FEFFE0).
        self.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255
                                                   blue:224.0/255 alpha:1];
        self.headerBar.backgroundColor = [UIColor colorWithRed:51.0/255
                                                            green:51.0/255
                                                             blue:51.0/255
                                                            alpha:1];
        self.header.textColor = [UIColor whiteColor];
    }

    BOOL isSameTopic = [self.message isSameTopicAsMessage:previousMessage];
    BOOL isSameSender = [self.message isSameSenderAsMessage:previousMessage];

    if (isSameTopic) {
        self.headerView.hidden = YES;
        [self.bodyView moveToPoint:CGPointZero];
        [self.bodyView resizeTo:self.contentView.size];
        [self.attributedTextView resizeTo:CGSizeMake(self.attributedTextView.width, self.bodyView.height - self.headerView.height)];

        if (isSameSender) {
            self.senderView.hidden = YES;
        }
    } else {
        [self.bodyView moveToPoint:CGPointMake(0, self.topOffset)];
        [self.bodyView resizeTo:CGSizeMake(self.width, self.contentView.height - self.headerView.height)];
        [self.attributedTextView resizeTo:CGSizeMake(self.attributedTextView.width, self.bodyView.height - self.headerView.height)];
    }
}

#pragma mark - DTAttributedTextContentViewDelegate
// Derived from example snippet from
// http://blog.smartlogicsolutions.com/2013/04/02/ios-development-dtattributedtextview-instead-of-uiwebview/
- (UIView *)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView
                          viewForLink:(NSURL *)url
                           identifier:(NSString *)identifier
                                frame:(CGRect)frame
{
    DTLinkButton *linkButton = [[DTLinkButton alloc] initWithFrame:frame];
    linkButton.URL = url;
    [linkButton addTarget:self action:@selector(linkClicked:) forControlEvents:UIControlEventTouchDown];

    return linkButton;
}

#pragma mark - Event handlers
- (IBAction)didTapStarButton:(id)sender {
    self.message.starred = !self.message.starred;
    self.starButton.selected = self.message.starred;
}

- (IBAction)linkClicked:(DTLinkButton *)sender
{
    if ([_delegate respondsToSelector:@selector(openLink:)])
    {
        [sender.URL baseURL];
        if (([[sender.URL host] isEqual:[[[ZulipAPIClient sharedClient] apiURL] host]])
            && ([[sender.URL path]  isEqual: @"/"]))
        {
            NSLog(@"FIXME: this application cannot yet open narrows");
        } else
        {
            [_delegate openLink:sender.URL];
        }
    }
}

@end
