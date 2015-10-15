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
#import "PreferencesWrapper.h"

#import "AFHTTPRequestOperation.h"
#import "AFJSONRequestOperation.h"

@interface LongPoller ()

@property (assign) int lastEventId;
@property (assign) int pollFailures;

@property (nonatomic, assign) BOOL waitingOnErrorRecovery;
@property (nonatomic, assign) BOOL persistentQueue;
@property (nonatomic, assign) BOOL needsSavingToDefaults;

@property (nonatomic, copy) EventBlock handler;
@property (nonatomic, copy) InitialData initialBlock;
@property (nonatomic, copy) ErrorHandler errorHandler;

@property (nonatomic, retain) AFHTTPRequestOperation *pollRequest;
@property (nonatomic, retain) ZulipAppDelegate *appDelegate;

@property (assign) double backoff;
@property (assign) double lastRequestTime;

// Persisten queue information
@property (nonatomic, retain) NSString *persistentName;

@end

@implementation LongPoller

- (id)initWithInitialBlock:(InitialData)initial andEventBlock:(EventBlock)events
{
    self = [super init];

    if (self) {
        [self reset];

        self.handler = events;
        self.initialBlock = initial;
        self.errorHandler = nil;
        self.persistentQueue = NO;
        self.persistentName = @"";
        self.needsSavingToDefaults = YES;

        self.appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    }

    return self;
}

- (void)reset
{
    self.lastEventId = -1;
    self.backoff = 0;
    self.pollFailures = 0;
    [self.pollRequest cancel];
    self.pollRequest = nil;
    self.queueId = @"";
    self.waitingOnErrorRecovery = NO;

    if (self.persistentQueue) {
        [[PreferencesWrapper sharedInstance] removeKey:self.persistentName];
    }
}

- (void)registerErrorHandler:(ErrorHandler)handler
{
    self.errorHandler = handler;
}

- (void)makePersistentWithUniqueName:(NSString *)name
{
    self.persistentName = name;
    self.persistentQueue = YES;
    self.needsSavingToDefaults = YES;
}

- (void)registerWithOptions:(NSDictionary *)opts
{
    // If we have a persistent queue, we load our queue id from NSUserDefaults
    // and use that automatically if it's found
    if (self.persistentQueue) {
        NSDictionary *queueData = [[PreferencesWrapper sharedInstance] persistentQueueWithName:self.persistentName];

        if (queueData) {
            self.queueId = [queueData objectForKey:@"queueId"];

            if (self.queueId && [queueData objectForKey:@"lastEventId"]) {
                self.lastEventId = [[queueData objectForKey:@"lastEventId"] intValue];
                self.needsSavingToDefaults = NO;

                // Notify we initially registered (even though we did no work)
                // Dispatch this on the main queue, because since we're short-circuiting
                // calling code might assume the callback is called asynchronously (and wants
                // to finish initializing).
                if (self.initialBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.initialBlock(nil);
                    });
                }

                // Try to long poll directly with our persistent queue id
                [self start];
                return;
            }
        }
    }

    [[ZulipAPIClient sharedClient] postPath:@"register" parameters:opts
                                    success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.pollFailures = 0;

        NSDictionary *json = (NSDictionary *)responseObject;

        self.queueId = [json objectForKey:@"queue_id"];
        self.lastEventId = [[json objectForKey:@"last_event_id"] intValue];

        if (self.initialBlock) {
            self.initialBlock(json);
        }

        if (self.needsSavingToDefaults && self.persistentQueue) {
            NSDictionary *data = @{@"queueId": self.queueId,
                                   @"lastEventId": @(self.lastEventId)};
            [[PreferencesWrapper sharedInstance] setPersistentQueue:data forName:self.persistentName];

            self.needsSavingToDefaults = NO;
        }
        // Start long polling
        [self start];

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failure doing registerWithOptions...retrying %@", [error localizedDescription]);

        if (self.pollFailures > 5) {
            [self.appDelegate showErrorScreen:@"Unable to connect to Zulip."];

        }
        self.pollFailures++;
        [self performSelector:@selector(registerWithOptions:) withObject:opts afterDelay:2];
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

      if (self.handler) {
          self.handler([json objectForKey:@"events"]);
      }

      [self performSelectorInBackground:@selector(longPoll) withObject: nil];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      NSLog(@"Failed to do long poll: %@", [error localizedDescription]);

      if (self.pollRequest == nil)  {
          // We were aborted by calling [reset], so stop the poll loop
          return;
      }

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
                  if (self.errorHandler) {
                      self.errorHandler();
                  }
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
