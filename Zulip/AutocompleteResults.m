//
//  AutocompleteResults.m
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import "AutocompleteResults.h"

@interface AutocompleteResults ()

@property (strong, nonatomic, readwrite) NSOrderedSet *prefixMatches;
@property (strong, nonatomic, readwrite) NSOrderedSet *nonPrefixMatches;
@property (assign, nonatomic, readwrite) BOOL isExactMatch;

@property (strong, nonatomic) id data;
@property (strong, nonatomic) NSString *query;

@end

@implementation AutocompleteResults

- (id)initWithArray:(NSArray *)data query:(NSString *)query {
    if (self = [super init]) {
        [self performSearchWithData:data query:query];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)data query:(NSString *)query {
    if (self = [super init]) {
        [self performSearchWithData:data query:query];
    }
    return self;
}

- (id)initWithSet:(NSSet *)data query:(NSString *)query {
    if (self = [super init]) {
        [self performSearchWithData:data.allObjects query:query];
    }
    return self;
}

- (void)performSearchWithData:(id)data query:(NSString *)query {
    self.data = data;
    self.query = query;

    NSMutableOrderedSet *mutablePrefixSet = [[NSMutableOrderedSet alloc] init];
    NSMutableOrderedSet *mutableNonPrefixSet = [[NSMutableOrderedSet alloc] init];

    for(NSString *candidate in data) {
        NSString *comparableObject = candidate;
        if ([data isKindOfClass:[NSDictionary class]]) {
            comparableObject = data[candidate];
        }

        NSUInteger index = [comparableObject rangeOfString:query options:NSCaseInsensitiveSearch].location;
        if (index == 0) {
            if ([comparableObject.lowercaseString isEqualToString:query.lowercaseString]) {
                self.isExactMatch = YES;
            }
            [mutablePrefixSet addObject:candidate];
        } else if (index != NSNotFound) {
            [mutableNonPrefixSet addObject:candidate];
        }
    }

    self.prefixMatches = [mutablePrefixSet copy];
    self.nonPrefixMatches = [mutableNonPrefixSet copy];
}

- (NSArray *)orderedResults {
    return [self.prefixMatches.array arrayByAddingObjectsFromArray:self.nonPrefixMatches.array];
}

@end
