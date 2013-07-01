#import "HumbugAPIClient.h"

#import "AFJSONRequestOperation.h"

@implementation HumbugAPIClient

static NSString *email = nil;

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
        BOOL debug = NO;
        NSString *apiURL;
        
        if (debug == YES) {
            apiURL = @"http://localhost:9991/api/v1";
        } else if (email != nil && [[email lowercaseString] hasSuffix:@"@humbughq.com"]) {
            apiURL = @"https://staging.humbughq.com/api/v1/";
        } else {
            apiURL = @"https://api.humbughq.com/v1/";
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

@end
