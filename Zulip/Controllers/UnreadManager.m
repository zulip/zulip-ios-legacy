//
//  UnreadManager.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/2/13.
//
//

#import "UnreadManager.h"

#import <Crashlytics/Crashlytics.h>

@interface UnreadManager ()

@property (nonatomic, retain) NSMutableDictionary *stream_unread;
@property (nonatomic, retain) NSMutableSet *home_unread;
@property (nonatomic, retain) NSMutableSet *pms_unread;

@end

NSString * const ZUnreadCountChangeNotification = @"UnreadMessageCountNotification";
NSString * const ZUnreadCountChangeNotificationData = @"UnreadMessageCountNotificationData";

@implementation UnreadManager

- (id)init
{
    self = [super init];
    if (self) {
        self.stream_unread = [[NSMutableDictionary alloc] init];
        self.home_unread = [[NSMutableSet alloc] init];
        self.pms_unread = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)handleIncomingMessage:(RawMessage *)message
{
    // We ignore new messages if they are read
    if ([message read])
        return;

    if (message.subscription) {
        if (message.subscription.name) {
            // Stream message that we have stream information for
            NSString *stream = message.subscription.name;

            NSMutableSet *stream_set = [self setForStream:stream];
            [stream_set addObject:message.messageID];
            [self.stream_unread setObject:stream_set forKey:stream];
        } else {
            // FIXME: Send log message to server once we have a runtime
            //        logging system.
            CLS_LOG(@"Found ZSubscription in message without name: %@", message);
        }
    } else {
        // PM
        [self.pms_unread addObject:message.messageID];
    }

    // In home view
    if (!message.subscription || message.subscription.in_home_view) {
        [self.home_unread addObject:message.messageID];
    }

    [self calculateCounts];
}

- (void)markMessageRead:(RawMessage *)message
{
    if (message.subscription) {
        NSString *stream = message.subscription.name;

        NSMutableSet *stream_set = [self setForStream:message.subscription.name];
        [stream_set removeObject:message.messageID];
        [self.stream_unread setObject:stream_set forKey:stream];
    } else {
        [self.pms_unread removeObject:message.messageID];
    }

    [self.home_unread removeObject:message.messageID];

    [self calculateCounts];
}

- (NSMutableSet *)setForStream:(NSString *)stream
{
    if (![self.stream_unread objectForKey:stream]) {
        [self.stream_unread setObject:[[NSMutableSet alloc] init] forKey:stream];
    }

    return [self.stream_unread objectForKey:stream];
}

- (void)calculateCounts
{
    NSMutableDictionary *unread_counts = [[NSMutableDictionary alloc] init];
    [unread_counts setObject:[NSNumber numberWithInt:[self.home_unread count]] forKey:@"home"];
    [unread_counts setObject:[NSNumber numberWithInt:[self.pms_unread count]] forKey:@"pms"];

    NSMutableDictionary *stream_counts = [[NSMutableDictionary alloc] init];
    for (NSString *streamName in self.stream_unread) {
        NSMutableSet *unread = [self.stream_unread objectForKey:streamName];
        [stream_counts setObject:[NSNumber numberWithInt:[unread count]] forKey:streamName];
    }
    [unread_counts setObject:stream_counts forKey:@"streams"];
    
    _unreadCounts = unread_counts;

    NSNotification *unreadChanges = [NSNotification notificationWithName:ZUnreadCountChangeNotification
                                                                  object:self
                                                                userInfo:@{ZUnreadCountChangeNotificationData: self.unreadCounts}];
    [[NSNotificationCenter defaultCenter] postNotification:unreadChanges];
}

@end
