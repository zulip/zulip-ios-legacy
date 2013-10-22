//
//  NSArray+Blocks.h
//  Zulip
//
//  Created by Leonardo Franchi on 10/22/13.
//
//

#import <Foundation/Foundation.h>

typedef BOOL(^FilterPredicate)(id obj);
typedef id(^MapPredicate)(id obj);

@interface NSArray (Blocks)

- (NSArray *)filter:(FilterPredicate)predicate;

- (NSArray *)map:(MapPredicate)predicate;

@end
