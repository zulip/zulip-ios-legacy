//
//  RawMessage.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/31/13.
//
//

#import <Foundation/Foundation.h>

#import "ZMessage.h"
#import "ZUser.h"
#import "ZSubscription.h"

/**
 This is a "non-NSManagedObject" ZMessage, for use in the message list.

 We can't use ZMessage objects directly in the message list, as we only want to save
 messages to Core Data in some cases (when loading into the Home View) and we can't
 generate NSManagedObject subclasses **without** loading them into core data

 Any changes made to this raw message need to be explicitly saved back to
 Core Data---use the - (void)save method for that.
 */
@interface RawMessage : NSObject

@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSString * avatar_url;
@property (nonatomic, retain) NSNumber * messageID;
@property (nonatomic, retain) NSString * stream_recipient;
@property (nonatomic, retain) NSString * subject;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSMutableSet *pm_recipients;
@property (nonatomic, retain) ZUser *sender;
@property (nonatomic, retain) ZSubscription *subscription;
@property (nonatomic, retain) NSArray *messageFlags;

- (void)save;

// Flag specific
- (BOOL)read;
- (void)setRead:(BOOL)unread;

+ (RawMessage *)allocFromZMessage:(ZMessage *)message;

@end
