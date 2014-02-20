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

typedef void(^RawMessageChangeHandler)(RawMessage *rawMsg);

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
@property (nonatomic, retain) NSSet *messageFlags;
@property (nonatomic, retain) NSAttributedString *attributedString;

@property (nonatomic, assign) BOOL munged;

// TODO (is this really needed?)
- (void)save;

// Flag specific
@property (nonatomic) BOOL read;
@property (nonatomic) BOOL starred;

- (void)addMessageFlag:(NSString *)flag;
- (void)removeMessageFlag:(NSString *)flag;

// Update handler
- (void)registerForChanges:(RawMessageChangeHandler)handler;

// Set to YES when updating from Zulip API, disables writeback
// of changes
@property (nonatomic, assign) BOOL disableUpdates;

+ (RawMessage *)allocFromZMessage:(ZMessage *)message;
@property (nonatomic, weak) ZMessage *linkedZMessage;

- (BOOL)isSameTopicAsMessage:(RawMessage *)otherMessage;
- (BOOL)isSameSenderAsMessage:(RawMessage *)otherMessage;
@end
