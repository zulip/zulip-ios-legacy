//
//  NarrowViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "NarrowViewController.h"
#import "ZulipAPIController.h"

@interface NarrowViewController ()

@end

@implementation NarrowViewController

- (id)initWithOperators:(NarrowOperators *)operators
{
    self = [super init];

    if (self) {
        self.operators = operators;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initialPopulate];
}

#pragma mark - StreamViewControllerDelegate

- (void)initialPopulate
{
    // Clear any messages first
    if ([self.messages count]) {
        [self clearMessages];
    }

    [[ZulipAPIController sharedInstance] loadMessagesAroundAnchor:[[ZulipAPIController sharedInstance] pointer]
                                                           before:12
                                                            after:0
                                                    withOperators:self.operators
                                                             opts:@{@"fetch_until_latest": @(YES)}
                                                  completionBlock:^(NSArray *messages) {
                                                      NSLog(@"Initially loaded %i messages!", [messages count]);

                                                      [self loadMessages:messages];
                                                  }];
}

- (void)resumePopulate
{
    NSLog(@"Resuming populating!");
}


@end
