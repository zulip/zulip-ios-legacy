//
//  NarrowOperators.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/1/13.
//
//

#import "NarrowOperators.h"

@interface NarrowOperators ()

@property (assign) BOOL home_view;

@property (nonatomic, retain) NSMutableArray *subpredicates;

@end

@implementation NarrowOperators

- (id)init
{
    self = [super init];
    if (self) {
        _subpredicates = [[NSMutableArray alloc] init];
        _home_view = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NarrowOperators *narrow = [[self class] allocWithZone:zone];
    if (narrow) {
        narrow->_home_view = self.home_view;
        narrow->_subpredicates = [self.subpredicates copyWithZone:zone];
    }
    return narrow;
}

+ (NarrowOperators *)operatorsFromMessage:(RawMessage *)msg
{
    NarrowOperators *narrow = [[NarrowOperators alloc] init];

    if (msg.subscription) {
        // Stream message, narrow to stream/topic
        // TODO we don't support narrowing to topics yet
        [narrow addStreamNarrow:msg.stream_recipient];
    } else {
        // PM
        [narrow setPrivateMessages];
    }

    return narrow;
}

- (void)setInHomeView
{
    [self.subpredicates addObject:[NSPredicate predicateWithFormat:@"( subscription == NIL ) OR ( subscription.in_home_view == YES )"]];
    self.home_view = YES;
}

- (BOOL)isHomeView
{
    return self.home_view;
}

- (void)setPrivateMessages
{
    [self.subpredicates addObject:@[@"is", @"private"]];
}

- (void)setMentions
{
    [self.subpredicates addObject:@[@"is", @"mentioned"]];
    self.isServerOnly = YES;
}

- (void)setStarred
{
    [self.subpredicates addObject:@[@"is", @"starred"]];
    self.isServerOnly = YES;
}

- (void)searchFor:(NSString *)query {
    [self.subpredicates addObject:@[@"search", query]];
    self.isServerOnly = YES;
}

- (BOOL)isPrivateMessages
{
    return ([self.subpredicates count] == 1) &&
           ([[[self.subpredicates objectAtIndex:0] objectAtIndex:0] isEqualToString:@"is"]) &&
           ([[[self.subpredicates objectAtIndex:0] objectAtIndex:1] isEqualToString:@"private"]);

}

- (void)addStreamNarrow:(NSString *)streamName
{
    [self.subpredicates addObject:@[@"stream", streamName]];
}

- (void)addUserNarrow:(NSString *)email {
    [self.subpredicates addObject:@[@"pm-with", email]];
}

- (NSString *)title
{
    if (self.home_view) {
        return @"Home";
    } else {
        if ([self.subpredicates count] == 1) {
            NSArray *pred = [self.subpredicates objectAtIndex:0];
            if ([pred count] > 0) {
                NSString *operator = [pred objectAtIndex:0];
                NSString *operand = [pred objectAtIndex:1];
                if ([@[@"stream", @"pm-with"] containsObject:operator]) {
                    return operand;
                } else if ([operator isEqualToString:@"is"] &&
                           [operand isEqualToString:@"private"]) {
                    return @"Private Messages";
                } else if ([operator isEqualToString:@"is"] &&
                           [operand isEqualToString:@"mentioned"]) {
                    return @"@-mentions";
                } else if ([operator isEqualToString:@"is"] &&
                           [operand isEqualToString:@"starred"]) {
                    return @"Starred Messages";
                } else if ([operator isEqualToString:@"search"]) {
                    return @"Search Results";
                }
            }
        }
    }

    return @"Zulip";
}

- (NSPredicate *)allocAsPredicate
{
    NSMutableArray *generated = [[NSMutableArray alloc] init];

    for (id pred in self.subpredicates) {
        if ([pred isKindOfClass:[NSPredicate class]]) {
            // Direct  NSPredicate
            [generated addObject:pred];
        } else if ([pred isKindOfClass:[NSArray class]]) {
            // server-style type:value narrow, convert to proper NSPredicate query
            NSString *operator = [pred objectAtIndex:0];
            NSString *operand = [pred objectAtIndex:1];

            if ([operator isEqualToString:@"is"] && [operand isEqualToString:@"private"]) {
                [generated addObject:[NSPredicate predicateWithFormat:@"subscription == NIL"]];
            } else if ([operator isEqualToString:@"stream"]) {
                [generated addObject:[NSPredicate predicateWithFormat:@"subscription.name LIKE %@", operand]];
            } else if ([operator isEqualToString:@"pm-with"]) {
                [generated addObject:[NSPredicate predicateWithFormat:@"subscription == NIL"]];
                [generated addObject:[NSPredicate predicateWithFormat:@"sender.email LIKE %@", operand]];
            }
        }
    }
    return [NSCompoundPredicate andPredicateWithSubpredicates:generated];
}

- (NSString *)allocAsJSONPayload
{
    NSMutableArray *narrow = [[NSMutableArray alloc] init];

    for (id pred in self.subpredicates) {
        if ([pred isKindOfClass:[NSPredicate class]]) {
            // Direct  NSPredicate, we can't use these on the server
            continue;
        } else if ([pred isKindOfClass:[NSArray class]]) {
            // server-style type:value narrow, convert to proper NSPredicate query
            NSString *operator = [pred objectAtIndex:0];
            NSString *operand = [pred objectAtIndex:1];

            [narrow addObject:@[operator, operand]];
        }
    }

    if ([narrow count] == 0) {
        return @"{}";
    }
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:narrow options:0 error:&error];
    if (error) {
        NSLog(@"Failed to convert narrow parmams to JSON: %@ %@", [error localizedDescription], [error userInfo]);
        return @"{}";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)acceptsMessage:(RawMessage *)msg
{
    // Filter out by elimination
    if (self.home_view) {
        if (msg.subscription && ![msg.subscription.in_home_view boolValue])
            return NO;
    }

    for (id pred in self.subpredicates) {
        if (![pred isKindOfClass:[NSArray class]])
            continue;

        NSString *operator = [pred objectAtIndex:0];
        NSString *operand = [pred objectAtIndex:1];

        if ([operator isEqualToString:@"is"]) {
            if ([operand isEqualToString:@"private"] &&
                msg.subscription != nil) {
                return NO;
            }
        } else if ([operator isEqualToString:@"stream"]) {
            if (![operand isEqualToString:msg.stream_recipient]) {
                return NO;
            }
        } else if ([operator isEqualToString:@"pm-with"]) {
            if (![operand isEqualToString:msg.sender.email]) {
                return NO;
            }
        }
    }
    return YES;
}

- (void)clear
{
    [self.subpredicates removeAllObjects];
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    } else if (!other || ![other isKindOfClass:[NarrowOperators class]]) {
        return NO;
    } else {
        NarrowOperators *them = (NarrowOperators *)other;

        if (self.home_view && them.home_view) {
            return YES;
        }
        if ([[self allocAsJSONPayload] isEqualToString:[them allocAsJSONPayload]]) {
            return YES;
        }
    }

    return NO;
}

- (NSUInteger)hash
{
    return [[self allocAsJSONPayload] hash];
}

@end
