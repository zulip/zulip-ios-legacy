//
//  StreamComposeView.h
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import <UIKit/UIKit.h>

@interface StreamComposeView : UIView

@property (readonly) CGFloat visibleHeight;

@property (strong, nonatomic) NSString *recipient;
@property (assign, nonatomic) BOOL isPrivate;

- (void)showSubjectBar;
- (void)hideSubjectBar;

@end
