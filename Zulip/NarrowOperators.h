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
@interface NarrowOperators : NSObject

- (void)setInHomeView;
- (void)setPrivateMessages;
- (void)addStreamNarrow:(NSString *)streamName;

- (BOOL)isHomeView;

- (NSString *)title;

- (NSPredicate *)allocAsPredicate;
- (NSString *)allocAsJSONPayload;
- (BOOL)acceptsMessage:(RawMessage *)msg;

- (void)clear;

- (BOOL)isEqual:(id)object;

@end
