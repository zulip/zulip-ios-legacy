//
//  NarrowOperators.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/1/13.
//
//

#import "NarrowOperators.h"

@interface NarrowOperators ()

@property (nonatomic, retain) NSMutableArray *subpredicates;

@end

@implementation NarrowOperators

- (id)init
{
    self = [super init];
    if (self) {
        _subpredicates = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setInHomeView
{
    [self.subpredicates addObject:[NSPredicate predicateWithFormat:@"( subscription == NIL ) OR ( subscription.in_home_view == YES )"]];
}

- (void)setPrivateMessages
{
    [self.subpredicates addObject:@[@"is", @"private"]];
}

- (void)addStreamNarrow:(NSString *)streamName
{
    [self.subpredicates addObject:@[@"stream", streamName]];
}

- (NSPredicate *)asPredicate
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

            if ([operator isEqualToString:@"is"] && [operand isEqualToString:@"pm"]) {
                [generated addObject:[NSPredicate predicateWithFormat:@"subscription == NIL"]];
            } else if ([operator isEqualToString:@"stream"]) {
                [generated addObject:[NSPredicate predicateWithFormat:@"subscription.name LIKE %@", operand]];
            }
        }
    }
    return [NSCompoundPredicate andPredicateWithSubpredicates:generated];
}

- (NSString *)asJSONPayload
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

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:narrow options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        NSLog(@"Failed to convert narrow parmams to JSON: %@ %@", [error localizedDescription], [error userInfo]);
        return @"{}";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)clear
{
    [self.subpredicates removeAllObjects];
}

@end
