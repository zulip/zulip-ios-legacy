//
//  ZulipAPIController.h
//  Humbug
//
//  Created by Leonardo Franchi on 7/24/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "ZSubscription.h"

@class StreamViewController;

/**
 This class is the entry point for making API requests to the Zulip API.

 It will add the desired data to Core Data, so to be notified of additions,
 use Core Data techniques.

 This class also takes care of long polling and translating long polling
 events into Core Data objects.
 */


@interface ZulipAPIController : NSObject

+ (ZulipAPIController *) sharedInstance;

// Registers for an event queue, and sets up initial data
- (void) registerForQueue;

@property(assign) long pointer;
@property(nonatomic, retain) StreamViewController *homeViewController;

@end
