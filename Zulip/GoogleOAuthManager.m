//
//  GoogleOAuthManager.m
//  Zulip
//
//  Created by Michael Walker on 1/31/14.
//
//

#import "GoogleOAuthManager.h"

#import "BrowserViewController.h"
#import "AFHTTPClient.h"

static NSString * const GoogleOAuthURLRoot = @"https://accounts.google.com/o/oauth2";
static NSString * const GoogleOAuthClientId = @"835904834568-gs3ncqe5d182tsh2brcv37hfc4vvdk07.apps.googleusercontent.com";
static NSString * const GoogleOAuthClientSecret = @"RVLTUT3UQrjJsYGjl-pha9bb";
static NSString * const GoogleOAuthAudience = @"835904834568-77mtr5mtmpgspj9b051del9i9r5t4g4n.apps.googleusercontent.com";
static NSString * const GoogleOAuthRedirectURI = @"http://localhost";
static NSString * const GoogleOAuthScope = @"email";

@interface GoogleOAuthManager ()<BrowserViewDelegate>
@property (copy, nonatomic) GoogleOAuthSuccessBlock success;
@property (copy, nonatomic) GoogleOAuthFailureBlock failure;

@end

@implementation GoogleOAuthManager

- (UIViewController *)showAuthScreenWithSuccess:(GoogleOAuthSuccessBlock)success failure:(GoogleOAuthFailureBlock)failure {
    self.success = success;
    self.failure = failure;

    NSString *urlString = [NSString stringWithFormat:@"%@/auth?scope=%@&redirect_uri=%@&response_type=code&client_id=%@", GoogleOAuthURLRoot, GoogleOAuthScope, GoogleOAuthRedirectURI, GoogleOAuthClientId];
    NSURL *url = [[NSURL alloc] initWithString:urlString];

    BrowserViewController *browser = [[BrowserViewController alloc] initWithUrls:url];
    browser.delegate = self;

    return browser;
}

- (BOOL)openURL:(NSURL *)url {
    if ([url.host isEqualToString:@"localhost"]) {
        NSArray *queryPairs = [url.query componentsSeparatedByString:@"&"];
        NSMutableDictionary *queryArgs = [NSMutableDictionary new];
        for (NSString *pair in queryPairs) {
            NSArray *components = [pair componentsSeparatedByString:@"="];
            queryArgs[components[0]] = components[1];
        }

        if (queryArgs[@"code"]) {
            [self fetchTokenForCode:queryArgs[@"code"]];
        } else {
            self.failure(nil);
        }
        return NO;
    }
    return YES;
}

- (void)fetchTokenForCode:(NSString *)code {
    NSDictionary *params = @{@"code": code,
                             @"client_id": GoogleOAuthClientId,
                             @"client_secret": GoogleOAuthClientSecret,
                             @"redirect_uri": GoogleOAuthRedirectURI,
                             @"grant_type": @"authorization_code",
                             @"audience": GoogleOAuthAudience,
                             @"aud": GoogleOAuthAudience};
    AFHTTPClient *client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:GoogleOAuthURLRoot]];
    [client postPath:@"token" parameters:params success:^(AFHTTPRequestOperation *operation, NSData *responseObject) {
        NSError *jsonError;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:&jsonError];
        if (!jsonError && result[@"id_token"]) {
            self.success(result);
        } else {
            self.failure(jsonError);
        }

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        self.failure(error);
    }];
}

@end
