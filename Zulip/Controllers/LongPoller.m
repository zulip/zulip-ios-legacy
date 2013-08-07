//
//  LongPoller.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/5/13.
//
//

#import "LongPoller.h"

#import "ZulipAPIClient.h"
#import "ZulipAppDelegate.h"

#import "AFHTTPRequestOperation.h"
#import "AFJSONRequestOperation.h"

@interface LongPoller ()

@property(assign) int lastEventId;
@property(assign) int pollFailures;

@property(nonatomic, assign) BOOL waitingOnErrorRecovery;

@property (nonatomic, copy) EventBlock handler;
@property (nonatomic, copy) InitialData initialBlock;

@property(nonatomic, retain) AFHTTPRequestOperation *pollRequest;
@property(nonatomic, retain) ZulipAppDelegate *appDelegate;

@property(assign) double backoff;
@property(assign) double lastRequestTime;

@end

@implementation LongPoller

- (id)initWithInitialBlock:(InitialData)initial andEventBlock:(EventBlock)events
{
    self = [super init];

    if (self) {
        self.handler = events;
        self.initialBlock = initial;

        self.appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    }

    return self;
}

- (void)reset
{
    self.handler = nil;
    self.lastEventId = -1;
    self.backoff = 0;
    self.pollFailures = 0;
    self.pollRequest = nil;
    self.queueId = @"";
    self.waitingOnErrorRecovery = NO;
}

- (void)registerWithOptions:(NSDictionary *)opts
{
    // Register for messages only
    [[ZulipAPIClient sharedClient] postPath:@"register" parameters:opts
                                    success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.pollFailures = 0;

        NSDictionary *json = (NSDictionary *)responseObject;

        self.queueId = [json objectForKey:@"queue_id"];
        self.lastEventId = [[json objectForKey:@"last_event_id"] intValue];

        if (self.initialBlock) {
            self.initialBlock(json);
        }

        // Start long polling
        [self start];

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failure doing registerWithOptions...retrying %@", [error localizedDescription]);

        if (self.pollFailures > 5) {
            [self.appDelegate showErrorScreen:@"Unable to connect to Zulip."];

        }
        self.pollFailures++;
        [self performSelector:@selector(registerWithOptions:) withObject:self afterDelay:2];
    }];
}

- (void) start
{
    if (self.pollRequest && [self.pollRequest isExecuting]) {
        [self.pollRequest cancel];
        self.pollRequest = 0;
    }

    [self performSelectorInBackground:@selector(longPoll) withObject:nil];
}


- (void) longPoll {
    while (([[NSDate date] timeIntervalSince1970] - self.lastRequestTime) < self.backoff) {
        [NSThread sleepForTimeInterval:.5];
    }

    self.lastRequestTime = [[NSDate date] timeIntervalSince1970];

    NSDictionary *fields = @{@"apply_markdown": @"false",
                             @"queue_id": self.queueId,
                             @"last_event_id": @(self.lastEventId)};

    NSMutableURLRequest *request = [[ZulipAPIClient sharedClient] requestWithMethod:@"GET" path:@"events" parameters:fields];
    [request setTimeoutInterval:120];

    self.pollRequest = [[ZulipAPIClient sharedClient] HTTPRequestOperationWithRequest:request
                                                                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
      NSDictionary *json = (NSDictionary *)responseObject;

      if (self.waitingOnErrorRecovery == YES) {
          self.waitingOnErrorRecovery = NO;
          [self.appDelegate dismissErrorScreen];
      }

      self.backoff = 0;
      self.pollFailures = 0;


      for (NSDictionary *event in [json objectForKey:@"events"]) {
          self.lastEventId = MAX(self.lastEventId, [[event objectForKey:@"id"] intValue]);
      }

      self.handler([json objectForKey:@"events"]);

      [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      NSLog(@"Failed to do long poll: %@", [error localizedDescription]);

      BOOL ignoreError = NO;

      // TODO
      // Ignore 504 errors from nginx, until I can figure out what they are
      if ([[operation response] statusCode] == 504) {
          ignoreError = YES;
      }

      if ([operation isKindOfClass:[AFJSONRequestOperation class]]) {
          NSDictionary *json = (NSDictionary *)[(AFJSONRequestOperation *)operation responseJSON];
          NSString *errorMsg = [json objectForKey:@"msg"];
          if ([[operation response] statusCode] == 400 &&
              ([errorMsg rangeOfString:@"too old"].location != NSNotFound ||
               [errorMsg rangeOfString:@"Bad event queue id"].location != NSNotFound)) {
                  // Reset if we've been GCed, we need a new event queue and all that
                  [self reset];
                  return;
              }
      }

      if (!ignoreError) {
          self.pollFailures++;
          [self adjustRequestBackoff];
          if (self.pollFailures > 5 && self.waitingOnErrorRecovery == NO) {
              self.waitingOnErrorRecovery = YES;
              [self.appDelegate showErrorScreen:@"Error getting messages. Please try again in a few minutes."];
          }
      }

      // Continue polling regardless
      [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    }];

    [[ZulipAPIClient sharedClient] enqueueHTTPRequestOperation:self.pollRequest];
}


- (void) adjustRequestBackoff
{
    if (self.backoff > 4) {
        return;
    }

    if (self.backoff == 0) {
        self.backoff = .8;
    } else if (self.backoff < 10) {
        self.backoff *= 2;
    } else {
        self.backoff = 10;
    }
}


@end
