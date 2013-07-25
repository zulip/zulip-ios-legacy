#import "AFHTTPClient.h"
/*
 Main API entry point for calling the Zulip API
 */
@interface ZulipAPIClient : AFHTTPClient

// Set the credentials before using the ZulipAPIClient via [ZulipAPIClient +sharedClient]
+ (void) setCredentials:(NSString *)user_email withAPIKey:(NSString *)key;

+ (ZulipAPIClient *) sharedClient;

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest success:(void ( ^ ) ( AFHTTPRequestOperation *operation , id responseObject ))success failure:(void ( ^ ) ( AFHTTPRequestOperation *operation , NSError *error ))failure;

- (void) logout;

@end
