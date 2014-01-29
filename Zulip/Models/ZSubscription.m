//
//  ZSubscription.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/25/13.
//
//

#import "ZSubscription.h"
#import "ZMessage.h"
#import "ZUser.h"
#import "ZulipAppDelegate.h"

@implementation ZSubscription

@dynamic color;
@dynamic in_home_view;
@dynamic invite_only;
@dynamic name;
@dynamic notifications;
@dynamic subscribers;
@dynamic messages;

- (id)initWithDictionary:(NSDictionary *)dict {
    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    self = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self.class) inManagedObjectContext:appDelegate.managedObjectContext];

    if (self) {
        self.color = dict[@"color"];
        self.in_home_view = dict[@"in_home_view"];
        self.invite_only = dict[@"invite_only"];
        self.name = dict[@"name"];
        self.notifications = dict[@"notifications"];
    }

    return self;
}

@end
