//
//  ComposeAutocompleteView.h
//  Zulip
//
//  Created by Michael Walker on 1/21/14.
//
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, ComposeAutocompleteType) {
    ComposeAutocompleteTypeUser,
    ComposeAutocompleteTypeStream,
    ComposeAutocompleteTypeTopic
};

@interface ComposeAutocompleteView : UIView<UITextFieldDelegate>

@property (weak, nonatomic) UIView *messageBody;

- (void)registerTextField:(UITextField *)textField
                  forType:(ComposeAutocompleteType)type;

@end
