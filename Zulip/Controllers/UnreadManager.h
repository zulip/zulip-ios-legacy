//
//  UnreadManager.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/2/13.
//
//

#import <Foundation/Foundation.h>

#import "RawMessage.h"

/**
 Keeps track of unread counts for streams and views,
 and sends out NSNotifications for when they change
 */
extern NSString * const ZUnreadCountChangeNotification;
extern NSString * const ZUnreadCountChangeNotificationData;

@interface UnreadManager : NSObject

@property (nonatomic, retain, readonly) NSDictionary *unreadCounts;

- (void)handleIncomingMessage:(RawMessage *)message;
- (void)markMessageRead:(RawMessage *)message;

@end
