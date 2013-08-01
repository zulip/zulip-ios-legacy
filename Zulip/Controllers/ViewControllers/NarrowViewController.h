//
//  NarrowViewController.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import <UIKit/UIKit.h>
#import "StreamViewController.h"
#import "NarrowOperators.h"

@interface NarrowViewController : StreamViewController

- (id)initWithOperators:(NarrowOperators *)operators;

@end
