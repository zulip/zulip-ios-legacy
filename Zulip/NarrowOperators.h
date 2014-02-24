//
//  NarrowOperators.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/1/13.
//
//

#import <Foundation/Foundation.h>
#import "RawMessage.h"

/**
 This represents a bunch of narrow operators, and can be converted into either an
 NSCompoundPredicate* for Core Data lookups or a Zulip-compatible JSON narrow blob
 */
@interface NarrowOperators : NSObject <NSCopying>

+ (NarrowOperators *) operatorsFromMessage:(RawMessage *)msg;

@property (assign, nonatomic) BOOL isServerOnly;

- (void)setInHomeView;
- (void)setPrivateMessages;
- (void)setMentions;
- (void)setStarred;
- (void)searchFor:(NSString *)query;
- (void)addStreamNarrow:(NSString *)streamName;
- (void)addUserNarrow:(NSString *)email;

- (BOOL)isHomeView;
- (BOOL)isPrivateMessages;

- (NSString *)title;

- (NSPredicate *)allocAsPredicate;
- (NSString *)allocAsJSONPayload;
- (BOOL)acceptsMessage:(RawMessage *)msg;

- (void)clear;

@end
