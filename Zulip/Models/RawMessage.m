//
//  RawMessage.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/31/13.
//
//

#import "RawMessage.h"

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
        [self addMessageFlags:@[@"read"]];
    } else {
        [self removeMessageFlags:@[@"read"]];
    }
}

- (void)addMessageFlags:(NSArray *)flags
{
    NSMutableArray *newFlags = [[NSMutableArray alloc] initWithArray:self.messageFlags];
    [newFlags addObjectsFromArray:flags];
    self.messageFlags = newFlags;
}

- (void)removeMessageFlags:(NSArray *)flags
{
    NSMutableArray *newFlags = [[NSMutableArray alloc] initWithArray:self.messageFlags];
    [newFlags removeObjectsInArray:flags];
    self.messageFlags = newFlags;
}

- (void)registerForChanges:(RawMessageChangeHandler)handler
{
    [self.changeHandlers addObject:[handler copy]];
}

- (void)setMessageFlags:(NSArray *)messageFlags
{
    _messageFlags = messageFlags;

    [self notifyOfChanges];
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

    return raw;
}


- (void)save
{
    // TODO
}
@end
