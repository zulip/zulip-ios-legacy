#import "AFHTTPClient.h"

/*
 Main API entry point for calling the Humbug API
 */
@interface HumbugAPIClient : AFHTTPClient

// Set the credentials before using the HumbugAPIClient via [HumbugAPIClient +sharedClient]
+ (void) setCredentials:(NSString *)user_email withAPIKey:(NSString *)key;

+ (HumbugAPIClient *) sharedClient;

@end
