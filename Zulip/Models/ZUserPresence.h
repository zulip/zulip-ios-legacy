//
//  ZUserPresence.h
//  Zulip
//
//  Created by Leonardo Franchi on 12/31/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

extern NSString *const ZUserPresenceStatusActive;
extern NSString *const ZUserPresenceStatusIdle;
extern NSString *const ZUserPresenceStatusOffline;
extern NSString *const ZUserPresenceStatusIgnore;

@class ZUser;

@interface ZUserPresence : NSManagedObject

@property (readonly) NSString * currentStatus;
@property (nonatomic, retain) NSString * status;
@property (nonatomic, retain) NSNumber * timestamp;
@property (nonatomic, retain) NSString * client;
@property (nonatomic, retain) ZUser *user;

@end
