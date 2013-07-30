//
//  NarrowViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "NarrowViewController.h"

@interface NarrowViewController ()

@end

@implementation NarrowViewController

- (id)initWithPredicate:(NSPredicate *)predicate
{
    self = [super init];

    if (self) {
        self.predicate = predicate;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initialPopulate];
}

#pragma mark - StreamViewControllerDelegate

- (NSString *)cacheName
{
    return [self.predicate predicateFormat];
}

@end
