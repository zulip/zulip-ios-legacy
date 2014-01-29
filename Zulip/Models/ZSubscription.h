//
//  ZSubscription.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/25/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZMessage, ZUser;

@interface ZSubscription : NSManagedObject

@property (nonatomic, retain) NSString * color;
@property (nonatomic, retain) NSNumber * in_home_view;
@property (nonatomic, retain) NSNumber * invite_only;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * notifications;
@property (nonatomic, retain) ZUser *subscribers;
@property (nonatomic, retain) NSSet *messages;
@end

@interface ZSubscription (CoreDataGeneratedAccessors)

- (id)initWithDictionary:(NSDictionary *)dict;

- (void)addMessagesObject:(ZMessage *)value;
- (void)removeMessagesObject:(ZMessage *)value;
- (void)addMessages:(NSSet *)values;
- (void)removeMessages:(NSSet *)values;

@end
