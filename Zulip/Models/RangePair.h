//
//  RangePair.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/6/13.
//
//

#import <Foundation/Foundation.h>

@interface RangePair : NSObject <NSCoding>

@property NSUInteger left;
@property NSUInteger right;

- (id) initWithStart:(NSUInteger)theStart andEnd:(NSUInteger)theEnd;
- (id) initForComparisonWith:(NSUInteger)messageID;

+ (void) extendRanges:(NSMutableArray *)rangePairs withRange:(RangePair*)newRange;
+ (RangePair*) getCurrentRangeOf:(NSUInteger)messageID inRangePairs:(NSArray *)rangePairs;

@end
