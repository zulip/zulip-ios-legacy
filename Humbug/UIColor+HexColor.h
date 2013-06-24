#import <UIKit/UIKit.h>

@interface UIColor (HexColor)

+ (UIColor *) colorWithHexString: (NSString *) hexString defaultColor:(UIColor *)defaultColor;

@end
