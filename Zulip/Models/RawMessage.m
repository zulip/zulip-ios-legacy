//
//  RawMessage.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/31/13.
//
//

#import "RawMessage.h"

#import "ZulipAppDelegate.h"
#import "ZulipAPIController.h"
#import "UnreadManager.h"

static NSString * const MessageFlagRead = @"read";
static NSString * const MessageFlagStarred = @"starred";

@interface RawMessage ()

@property (nonatomic, retain) NSMutableSet *changeHandlers;
@end

@implementation RawMessage

- (id)init
{
    self = [super init];

    if (self) {
        self.changeHandlers = [[NSMutableSet alloc] init];
        self.pm_recipients = [[NSMutableSet alloc] init];
        self.linkedZMessage = nil;
        self.messageFlags = [[NSSet alloc] init];
        self.disableUpdates = NO;
    }

    return self;
}

- (BOOL)read
{
    return [self.messageFlags containsObject:MessageFlagRead];
}

- (void)setRead:(BOOL)read
{
    if ([self read] == read) {
        return;
    }

    if (read) {
        [self addMessageFlag:MessageFlagRead];
    } else {
        [self removeMessageFlag:MessageFlagRead];
    }

    if (read) {
        [[[ZulipAPIController sharedInstance] unreadManager] markMessageRead:self];
    }
}

- (BOOL)starred {
    return [self.messageFlags containsObject:MessageFlagStarred];
}

- (void)setStarred:(BOOL)starred
{
    if (starred) {
        [self addMessageFlag:MessageFlagStarred];
    } else {
        [self removeMessageFlag:MessageFlagStarred];
    }
}

- (void)addMessageFlag:(NSString *)flag
{
    NSMutableSet *newFlags = [[NSMutableSet alloc] initWithSet:self.messageFlags];
    [newFlags addObject:flag];

    // Save back to the server if there is a change
    if (![newFlags isEqualToSet:self.messageFlags] && !self.disableUpdates) {
        [[ZulipAPIController sharedInstance] sendMessageFlagsUpdated:self withOperation:@"add" andFlag:flag];
    }

    self.messageFlags = newFlags;
}

- (void)removeMessageFlag:(NSString *)flag
{
    NSMutableSet *newFlags = [[NSMutableSet alloc] initWithSet:self.messageFlags];
    [newFlags removeObject:flag];

    // Save back to the server if there is a change
    if (![newFlags isEqualToSet:self.messageFlags] && !self.disableUpdates) {
        [[ZulipAPIController sharedInstance] sendMessageFlagsUpdated:self withOperation:@"remove" andFlag:flag];
    }

    self.messageFlags = newFlags;
}

- (void)registerForChanges:(RawMessageChangeHandler)handler
{
    [self.changeHandlers addObject:[handler copy]];
}

- (void)setMessageFlags:(NSSet *)messageFlags
{
    if ([_messageFlags isEqualToSet:messageFlags]) {
        return;
    }

    _messageFlags = messageFlags;

    [self notifyOfChanges];

    // Save to Core Data if necessary
    if (self.linkedZMessage) {
        if (![self.messageFlags isEqualToSet:self.linkedZMessage.messageFlags]) {
            [self.linkedZMessage setMessageFlags:self.messageFlags];
            ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];

            NSError *error = nil;
            [[appDelegate managedObjectContext] save:&error];
            if (error) {
                NSLog(@"Error saving flags from RawMessage to ZMessage: %@ %@", [error localizedDescription], [error userInfo]);
            }
        }
    }
}

- (void)notifyOfChanges
{
    for (RawMessageChangeHandler handler in self.changeHandlers) {
        handler(self);
    }
}

+ (RawMessage *)allocFromZMessage:(ZMessage *)message
{
    RawMessage *raw = [[RawMessage alloc] init];

    NSArray *string_props = @[@"content", @"avatar_url", @"stream_recipient", @"subject", @"type"];
    for (NSString *prop in string_props) {
        [raw setValue:[message valueForKey:prop] forKey:prop];
    }
    raw.messageID = message.messageID;
    raw.timestamp = message.timestamp;
    raw.pm_recipients = [NSMutableSet setWithSet:message.pm_recipients];
    raw.sender = message.sender;

    raw.messageFlags = [message messageFlags];

    raw.linkedZMessage = message;

    return raw;
}

- (void)save
{
    // TODO
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ZMessage sender: %@ id:%li>", self.sender.full_name, [self.messageID longValue]];
}

- (BOOL)isSameTopicAsMessage:(RawMessage *)otherMessage {
    if ([self.type isEqualToString:@"stream"]) {
        return [self.stream_recipient isEqualToString:otherMessage.stream_recipient] && [self.subject isEqualToString:otherMessage.subject];
    } else if ([self.type isEqualToString:@"private"]) {
        return [self.pm_recipients isEqualToSet:otherMessage.pm_recipients];
    }

    return NO;

}

- (BOOL)isSameSenderAsMessage:(RawMessage *)otherMessage {
    return [self.sender isEqual:otherMessage.sender];
}


@end
