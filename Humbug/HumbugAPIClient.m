#import "HumbugAPIClient.h"

#import "AFJSONRequestOperation.h"

@implementation HumbugAPIClient

static NSString *email = nil;
static BOOL debug = NO;

+ (void)setCredentials:(NSString *)user_email withAPIKey:(NSString *)key {
    [user_email retain];
    email = user_email;

    [[HumbugAPIClient sharedClient] setAuthorizationHeaderWithUsername:email password:key];

}

// Singleton
+ (HumbugAPIClient *)sharedClient {
    static HumbugAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *apiURL;
        
        if (debug == YES) {
            apiURL = @"http://localhost:9991/api/v1";
        } else if (email != nil && [[email lowercaseString] hasSuffix:@"@zulip.com"]) {
            apiURL = @"https://staging.zulip.com/api/v1/";
        } else {
            apiURL = @"https://api.zulip.com/v1/";
        }

        NSLog(@"Loading URL: %@", apiURL);
        _sharedClient = [[HumbugAPIClient alloc] initWithBaseURL:[NSURL URLWithString:apiURL]];
    });

    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }

    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];

    // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
    [self setDefaultHeader:@"Accept" value:@"application/json"];

    return self;
}

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest success:(void ( ^ ) ( AFHTTPRequestOperation *operation , id responseObject ))success failure:(void ( ^ ) ( AFHTTPRequestOperation *operation , NSError *error ))failure {
    // Reimplement to print out error messages from JSON content
    id my_failure = ^( AFHTTPRequestOperation *operation , NSError *error ) {
        if (failure) {
            failure(operation, error);
        }

        // Log 'msg' key from JSON payload if it exists
        if ([operation isKindOfClass:[AFJSONRequestOperation class]]) {
            NSDictionary *json = (NSDictionary *)[(AFJSONRequestOperation *)operation responseJSON];
            NSString *errorMsg = [json objectForKey:@"msg"];
            if (errorMsg) {
                NSLog(@"Humbug API Error Message: %@", errorMsg);
            }
        }
    };

    if (debug)
        NSLog(@"Sending API request for: %@", [[urlRequest URL] path]);
    return [super HTTPRequestOperationWithRequest:urlRequest success:success failure:my_failure];
}
@end
