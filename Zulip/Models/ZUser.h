//
//  ZUser.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/29/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZMessage, ZSubscription;

@interface ZUser : NSManagedObject

@property (nonatomic, retain) NSString * avatar_url;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * full_name;
@property (nonatomic, retain) NSNumber * userID;
@property (nonatomic, retain) NSSet *received_pms;
@property (nonatomic, retain) NSSet *sent_messages;
@property (nonatomic, retain) NSSet *subscriptions;
@end

@interface ZUser (CoreDataGeneratedAccessors)

- (void)addReceived_pmsObject:(ZMessage *)value;
- (void)removeReceived_pmsObject:(ZMessage *)value;
- (void)addReceived_pms:(NSSet *)values;
- (void)removeReceived_pms:(NSSet *)values;

- (void)addSent_messagesObject:(ZMessage *)value;
- (void)removeSent_messagesObject:(ZMessage *)value;
- (void)addSent_messages:(NSSet *)values;
- (void)removeSent_messages:(NSSet *)values;

- (void)addSubscriptionsObject:(ZSubscription *)value;
- (void)removeSubscriptionsObject:(ZSubscription *)value;
- (void)addSubscriptions:(NSSet *)values;
- (void)removeSubscriptions:(NSSet *)values;

@end
