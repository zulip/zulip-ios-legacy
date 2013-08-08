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
    }

    return self;
}

- (BOOL)read
{
    return [self.messageFlags containsObject:@"read"];
}

- (void)setRead:(BOOL)read
{
    if ([self read] == read) {
        return;
    }

    if (read) {
        [self addMessageFlag:@"read"];
    } else {
        [self removeMessageFlag:@"read"];
    }

    if (read) {
        [[[ZulipAPIController sharedInstance] unreadManager] markMessageRead:self];
    }
}

- (void)addMessageFlag:(NSString *)flag
{
    NSMutableSet *newFlags = [[NSMutableSet alloc] initWithSet:self.messageFlags];
    [newFlags addObject:flag];

    // Save back to the server if there is a change
    if (![newFlags isEqualToSet:self.messageFlags]) {
        [[ZulipAPIController sharedInstance] sendMessageFlagsUpdated:self withOperation:@"add" andFlag:flag];
    }

    self.messageFlags = newFlags;
}

- (void)removeMessageFlag:(NSString *)flag
{
    NSMutableSet *newFlags = [[NSMutableSet alloc] initWithSet:self.messageFlags];
    [newFlags removeObject:flag];

    self.messageFlags = newFlags;
}

- (void)registerForChanges:(RawMessageChangeHandler)handler
{
    [self.changeHandlers addObject:[handler copy]];
}

- (void)setMessageFlags:(NSSet *)messageFlags
{
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

@end
