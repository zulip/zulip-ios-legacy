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

@interface LongPoller : NSObject

@property (nonatomic, retain) NSString *queueId;
@property (nonatomic, assign) int lastEventID;

- (id)initWithInitialBlock:(InitialData)initial andEventBlock:(EventBlock)events;

- (void)registerWithOptions:(NSDictionary *)opts;
- (void)reset;

@end
