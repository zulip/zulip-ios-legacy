//
//  StreamComposeView.h
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import <UIKit/UIKit.h>

@class RawMessage;
@class ComposeAutocompleteView;
@class ZUser;

@protocol StreamComposeViewDelegate <NSObject>
- (void)willShowComposeView;
@end

@interface StreamComposeView : UIView

@property (readonly) CGFloat visibleHeight;

@property (weak, nonatomic) id<StreamComposeViewDelegate> delegate;

@property (strong, nonatomic) NSString *defaultRecipient;
@property (assign, nonatomic) BOOL isPrivate;
@property (strong, nonatomic) ComposeAutocompleteView *autocompleteView;

- (id)initWithAutocompleteView:(ComposeAutocompleteView *)autocompleteView;

- (void)showComposeViewForMessage:(RawMessage *)message;
- (void)showComposeViewForUser:(ZUser *)message;

// Shows the compose view as if the user tapped on the compose box
- (void)showOneTimePrivateCompose;

- (void)showSubjectBar;
- (void)hideSubjectBar;

@end
