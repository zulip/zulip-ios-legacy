//
//  ZUserPresence.m
//  Zulip
//
//  Created by Leonardo Franchi on 12/31/13.
//
//

#import "ZUserPresence.h"
#import "ZUser.h"

static const NSTimeInterval ZUserPresenceTimeout = 140; // In seconds

NSString *const ZUserPresenceStatusActive = @"active";
NSString *const ZUserPresenceStatusIdle = @"idle";
NSString *const ZUserPresenceStatusOffline = @"offline";
NSString *const ZUserPresenceStatusIgnore = @"ignore";

static NSString *const ZUserPresenceClientWebsite = @"website";

@implementation ZUserPresence

@dynamic status;
@dynamic timestamp;
@dynamic client;
@dynamic user;

- (NSString *)currentStatus {
    if (![self.client isEqualToString:ZUserPresenceClientWebsite]) {
        return ZUserPresenceStatusIgnore;
    } else if (self.isCurrent) {
        return self.status;
    } else {
        return ZUserPresenceStatusOffline;
    }
}

- (BOOL)isCurrent {
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:[self.timestamp doubleValue]];
    return [[NSDate date] timeIntervalSinceDate:timestamp] < ZUserPresenceTimeout;
}

@end
