//
//  NarrowViewController.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import <UIKit/UIKit.h>
#import "StreamViewController.h"

@interface NarrowViewController : StreamViewController

@property (nonatomic, retain) NSPredicate *predicate;

- (id)initWithPredicate:(NSPredicate *)predicate;

@end
