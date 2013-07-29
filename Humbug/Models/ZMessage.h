//
//  ZMessage.h
//  Humbug
//
//  Created by Leonardo Franchi on 7/25/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ZSubscription, ZUser;

@interface ZMessage : NSManagedObject

@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSString * gravatar_hash;
@property (nonatomic, retain) NSNumber * messageID;
@property (nonatomic, retain) NSString * stream_recipient;
@property (nonatomic, retain) NSString * subject;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSSet *pm_recipients;
@property (nonatomic, retain) ZUser *sender;
@property (nonatomic, retain) ZSubscription *subscription;
@end

@interface ZMessage (CoreDataGeneratedAccessors)

- (void)addPm_recipientsObject:(ZUser *)value;
- (void)removePm_recipientsObject:(ZUser *)value;
- (void)addPm_recipients:(NSSet *)values;
- (void)removePm_recipients:(NSSet *)values;

@end
