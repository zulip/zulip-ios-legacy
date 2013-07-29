//
//  ZUser.h
//  Humbug
//
//  Created by Leonardo Franchi on 7/25/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZMessage, ZSubscription;

@interface ZUser : NSManagedObject

@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * full_name;
@property (nonatomic, retain) NSString * gravatar_hash;
@property (nonatomic, retain) NSNumber * userID;
@property (nonatomic, retain) ZMessage *received_pm;
@property (nonatomic, retain) NSSet *sent_messages;
@property (nonatomic, retain) NSSet *subscriptions;
@end

@interface ZUser (CoreDataGeneratedAccessors)

- (void)addSent_messagesObject:(ZMessage *)value;
- (void)removeSent_messagesObject:(ZMessage *)value;
- (void)addSent_messages:(NSSet *)values;
- (void)removeSent_messages:(NSSet *)values;

- (void)addSubscriptionsObject:(ZSubscription *)value;
- (void)removeSubscriptionsObject:(ZSubscription *)value;
- (void)addSubscriptions:(NSSet *)values;
- (void)removeSubscriptions:(NSSet *)values;

@end
