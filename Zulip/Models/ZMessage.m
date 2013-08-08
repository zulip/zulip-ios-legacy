//
//  ZMessage.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/2/13.
//
//

#import "ZMessage.h"
#import "ZSubscription.h"
#import "ZUser.h"


@implementation ZMessage

@dynamic avatar_url;
@dynamic content;
@dynamic messageID;
@dynamic stream_recipient;
@dynamic subject;
@dynamic timestamp;
@dynamic type;
@dynamic flagData;
@dynamic pm_recipients;
@dynamic sender;
@dynamic subscription;

// MANUALLY ADDED BELOW THIS LINE
@synthesize linkedRawMessage;

- (NSSet *)messageFlags
{
    if (!self.flagData) {
        return [[NSSet alloc] init];
    }
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:self.flagData];
}

- (void)setMessageFlags:(NSSet *)flags
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:flags];
    self.flagData = data;
}

@end
