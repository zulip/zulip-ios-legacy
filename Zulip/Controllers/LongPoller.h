//
//  LongPoller.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/5/13.
//
//

#import <Foundation/Foundation.h>

typedef void(^EventBlock)(NSArray *events);
typedef void(^InitialData)(NSDictionary *data);
typedef void(^ErrorHandler)(void);

@interface LongPoller : NSObject

@property (nonatomic, retain) NSString *queueId;

- (id)initWithInitialBlock:(InitialData)initial andEventBlock:(EventBlock)events;
- (void)registerErrorHandler:(ErrorHandler)handler;

- (void)registerWithOptions:(NSDictionary *)opts;
- (void)reset;

// If this queue is to be persistent (saving its queueid across restarts,
// and attempting to reuse it).
- (void)makePersistentWithUniqueName:(NSString *)name;

@end
