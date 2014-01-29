//
//  ComposeAutocompleteView.h
//  Zulip
//
//  Created by Michael Walker on 1/21/14.
//
//

#import <UIKit/UIKit.h>

@class StreamViewController;

typedef NS_ENUM(NSUInteger, ComposeAutocompleteType) {
    ComposeAutocompleteTypeUser,
    ComposeAutocompleteTypeStream,
    ComposeAutocompleteTypeTopic
};

@interface ComposeAutocompleteView : UITableView<UITextFieldDelegate>

@property (weak, nonatomic) UIView *messageBody;
@property (weak, nonatomic) StreamViewController *messageDelegate;

- (void)registerTextField:(UITextField *)textField
                  forType:(ComposeAutocompleteType)type;
- (void)resetRegisteredTextFields;
@end
