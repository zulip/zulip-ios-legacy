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

- (void)addStreamNarrow:(NSString *)streamName
{
    [self.subpredicates addObject:@[@"stream", streamName]];
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
    NSData *data = [NSJSONSerialization dataWithJSONObject:narrow options:NSJSONWritingPrettyPrinted error:&error];
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

@end
