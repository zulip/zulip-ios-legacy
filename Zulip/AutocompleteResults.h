//
//  AutocompleteResults.h
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import <Foundation/Foundation.h>

@interface AutocompleteResults : NSObject

@property (readonly) NSOrderedSet *prefixMatches;
@property (readonly) NSOrderedSet *nonPrefixMatches;
@property (readonly) NSArray *orderedResults;
@property (readonly) BOOL isExactMatch;

- (id)initWithArray:(NSArray *)data query:(NSString *)query;
- (id)initWithDictionary:(NSDictionary *)data query:(NSString *)query;
- (id)initWithSet:(NSSet *)data query:(NSString *)query;


@end
