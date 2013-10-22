//
//  NSArray+Blocks.m
//  Zulip
//
//  Created by Leonardo Franchi on 10/22/13.
//
//

#import "NSArray+Blocks.h"

@implementation NSArray (Blocks)

- (NSArray *)filter:(FilterPredicate)predicate
{
    if (!predicate) {
        return self;
    }

    NSIndexSet *indices = [self indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return predicate(obj);
    }];

    return [self objectsAtIndexes:indices];
}

- (NSArray *)map:(MapPredicate)predicate
{
    if (!predicate) {
        return self;
    }

    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (id obj in self) {
        id newObj = predicate(obj);
        [newArray addObject:newObj ? newObj : [NSNull null]];
    }

    return newArray;
}
@end
