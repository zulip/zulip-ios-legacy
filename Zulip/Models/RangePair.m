//
//  RangePair.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/6/13.
//
//

#import "RangePair.h"

@implementation RangePair

- (id) initWithStart:(NSUInteger)theStart andEnd:(NSUInteger)theEnd
{
    if (self = [super init])
    {
        self.left = theStart;
        self.right = theEnd;
        if (self.left >= self.right) {
            NSLog(@"Invalid range given to RangePair: [%i, %i]", (int)self.left, (int)self.right);
            NSAssert2(self.left < self.right, @"invalid range given: [%i, %i]", (int)self.left, (int)self.right);
        }

    }
    return self;
}

- (id) initForComparisonWith:(NSUInteger)messageID
{
    // omit checking for valid range
    if (self = [super init]) {
        self.left = messageID;
        self.right = messageID;
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];

    if (self) {
        self.left = [[aDecoder decodeObjectForKey:@"left"] unsignedIntegerValue];
        self.right = [[aDecoder decodeObjectForKey:@"right"] unsignedIntegerValue];
    }

    return self;
}

+ (void) extendRanges:(NSMutableArray *)rangePairs withRange:(RangePair*)newRange;
{

    // binary search for new.left in rangePairs.rights. Save that part of the array as "head"
    NSUInteger indexOfRangePairHead = [rangePairs indexOfObject:newRange inSortedRange:(NSRange){0, [rangePairs count]} options:NSBinarySearchingInsertionIndex|NSBinarySearchingFirstEqual usingComparator:^(RangePair * left, RangePair * right) {
        if (left.right < right.left) {
            return NSOrderedAscending;
        }
        if (left.left > right.right) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    // binary search for new.right in rangePairs.lefts. Save that part of the array as "tail"
    NSUInteger indexOfRangePairTail = [rangePairs indexOfObject:newRange inSortedRange:(NSRange){0, [rangePairs count]} options:NSBinarySearchingInsertionIndex|NSBinarySearchingLastEqual usingComparator:^(RangePair *left, RangePair *right) {
        if (left.right < right.left) {
            return NSOrderedAscending;
        }
        if (left.left > right.right) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    // We now partition the rangePairs like so:
    // [0..indexHead-1|indexHead..indexTail-1|indexTail..last]
    NSArray* head = [rangePairs subarrayWithRange:NSMakeRange(0, indexOfRangePairHead)];
    NSArray* middle = [rangePairs subarrayWithRange:NSMakeRange(indexOfRangePairHead, indexOfRangePairTail-indexOfRangePairHead)];
    NSArray* tail = [rangePairs subarrayWithRange:NSMakeRange(indexOfRangePairTail, [rangePairs count]-indexOfRangePairTail)];

    [rangePairs removeAllObjects];

    if(indexOfRangePairTail != indexOfRangePairHead) {
        for (NSUInteger i=0; i<[middle count]; ++i) {
            newRange.left = MIN([middle[i] left], [newRange left]);
            newRange.right = MAX([middle[i] right], [newRange right]);
        }
    }

    [rangePairs addObjectsFromArray:head];
    [rangePairs addObject:newRange];
    [rangePairs addObjectsFromArray:tail];
}


+ (RangePair*) getCurrentRangeOf:(NSUInteger)messageID inRangePairs:(NSArray *)rangePairs
{
    RangePair* messageRange = [[RangePair alloc] initForComparisonWith:messageID];
    NSUInteger indexOfPossibleCurrentRange = [rangePairs indexOfObject:messageRange inSortedRange:(NSRange){0, [rangePairs count]} options:NSBinarySearchingInsertionIndex|NSBinarySearchingFirstEqual usingComparator:^(RangePair * left, RangePair * right) {
        if (left.right < right.left) {
            return NSOrderedAscending;
        }
        if (left.left > right.right) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    if (indexOfPossibleCurrentRange == [rangePairs count]) {
        return nil;
    }

    RangePair* possibleCurrentRange = [rangePairs objectAtIndex:indexOfPossibleCurrentRange];
    if (messageID >= possibleCurrentRange.left && messageID <= possibleCurrentRange.right) {
        return possibleCurrentRange;
    }

    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RangePair [%i, %i]>", (int)self.left, (int)self.right];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.left] forKey:@"left"];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.right] forKey:@"right"];
}


@end
