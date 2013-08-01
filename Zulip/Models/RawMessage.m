//
//  RawMessage.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/31/13.
//
//

#import "RawMessage.h"

@implementation RawMessage

- (id)init
{
    self = [super init];

    if (self) {
        self.pm_recipients = [[NSMutableSet alloc] init];
    }

    return self;
}

+ (RawMessage *)fromZMessage:(ZMessage *)message
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

    return raw;
}

- (void)save
{
    // TODO
}
@end
