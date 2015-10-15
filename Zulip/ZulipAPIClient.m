#import "ZulipAPIClient.h"

#import "AFJSONRequestOperation.h"

@implementation ZulipAPIClient

static NSString *email = nil;
static BOOL debug = NO;

+ (void)setCredentials:(NSString *)userEmail withAPIKey:(NSString *)key {
    email = userEmail;

    [[ZulipAPIClient sharedClient] setAuthorizationHeaderWithUsername:email password:key];

}

+ (void)setEmailForDomain:(NSString *)userEmail
{
    email = userEmail;
}

static dispatch_once_t *onceTokenPointer;

// Singleton
+ (ZulipAPIClient *)sharedClient {
    static ZulipAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    onceTokenPointer = &onceToken;
    dispatch_once(&onceToken, ^{
        NSString *apiURLString;

        if (debug == YES) {
            apiURLString = @"http://localhost:9991/api/v1";
        } else {
            apiURLString = @"https://api.zulip.com/v1/";
        }

        NSLog(@"Loading URL: %@", apiURLString);
        NSURL *apiURL = [NSURL URLWithString:apiURLString];
        _sharedClient = [[ZulipAPIClient alloc] initWithBaseURL:apiURL];

        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *userAgent = [NSString stringWithFormat:@"ZulipiOS/%@ (%@; %@)", version, [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]];

        [_sharedClient setDefaultHeader:@"User-Agent" value:userAgent];

        _sharedClient.apiURL = apiURL;
    });

    return _sharedClient;
}

- (void)logout {
    *onceTokenPointer = 0;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }

    self.client = @"ios";

    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];

    // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
    [self setDefaultHeader:@"Accept" value:@"application/json"];

    return self;
}

#pragma mark - AFHTTPClient reimplementations

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
                NSLog(@"Zulip API Error Message: %@", errorMsg);
            }
        }
    };

    if (debug)
        NSLog(@"Sending API request for: %@", [[urlRequest URL] path]);

    return [super HTTPRequestOperationWithRequest:urlRequest success:success failure:my_failure];
}

// Send client string with all requests

- (NSDictionary *)addClientToParams:(NSDictionary *)parameters {
    if (!parameters) {
        parameters = @{};
    }
    NSMutableDictionary *mutatedParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [mutatedParams setObject:self.client forKey:@"client"];
    return mutatedParams;
}

- (void)getPath:(NSString *)path parameters:(NSDictionary *)parameters success:(void ( ^ ) ( AFHTTPRequestOperation *operation , id responseObject ))success failure:(void ( ^ ) ( AFHTTPRequestOperation *operation , NSError *error ))failure
{
    return [super getPath:path parameters:[self addClientToParams:parameters] success:success failure:failure];
}

- (void)patchPath:(NSString *)path parameters:(NSDictionary *)parameters success:(void ( ^ ) ( AFHTTPRequestOperation *operation , id responseObject ))success failure:(void ( ^ ) ( AFHTTPRequestOperation *operation , NSError *error ))failure
{
    return [super patchPath:path parameters:[self addClientToParams:parameters] success:success failure:failure];
}

- (void)postPath:(NSString *)path parameters:(NSDictionary *)parameters success:(void ( ^ ) ( AFHTTPRequestOperation *operation , id responseObject ))success failure:(void ( ^ ) ( AFHTTPRequestOperation *operation , NSError *error ))failure
{
    return [super postPath:path parameters:[self addClientToParams:parameters] success:success failure:failure];
}

- (void)putPath:(NSString *)path parameters:(NSDictionary *)parameters success:(void ( ^ ) ( AFHTTPRequestOperation *operation , id responseObject ))success failure:(void ( ^ ) ( AFHTTPRequestOperation *operation , NSError *error ))failure
{
    return [super putPath:path parameters:[self addClientToParams:parameters] success:success failure:failure];
}

@end
