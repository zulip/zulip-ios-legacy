//
//  ZUserPresence.h
//  Zulip
//
//  Created by Leonardo Franchi on 12/31/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZUser;

@interface ZUserPresence : NSManagedObject

@property (nonatomic, retain) NSString * status;
@property (nonatomic, retain) NSNumber * timestamp;
@property (nonatomic, retain) NSString * client;
@property (nonatomic, retain) ZUser *user;

@end
