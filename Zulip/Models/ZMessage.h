//
//  ZMessage.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/2/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZSubscription, ZUser, RawMessage;

@interface ZMessage : NSManagedObject

@property (nonatomic, retain) NSString * avatar_url;
@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSNumber * messageID;
@property (nonatomic, retain) NSString * stream_recipient;
@property (nonatomic, retain) NSString * subject;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSData * flagData;
@property (nonatomic, retain) NSSet *pm_recipients;
@property (nonatomic, retain) ZUser *sender;
@property (nonatomic, retain) ZSubscription *subscription;

// NOTE: These two methods below have been manually added,
// when regenerating this file make sure to keep them!
// Do not use these directly. Use RawMessage objects
// to manipulate messages
- (NSSet *)messageFlags;
- (void)setMessageFlags:(NSSet *)flags;

// NOTE added manually, retain when regenerating!
@property (nonatomic, retain) RawMessage *linkedRawMessage;

@end

@interface ZMessage (CoreDataGeneratedAccessors)

- (void)addPm_recipientsObject:(ZUser *)value;
- (void)removePm_recipientsObject:(ZUser *)value;
- (void)addPm_recipients:(NSSet *)values;
- (void)removePm_recipients:(NSSet *)values;

@end
