//
//  GoogleOAuthManager.h
//  Zulip
//
//  Created by Michael Walker on 1/31/14.
//
//

#import <Foundation/Foundation.h>

typedef void (^GoogleOAuthSuccessBlock)(NSDictionary *result);
typedef void (^GoogleOAuthFailureBlock)(NSError *error);

@interface GoogleOAuthManager : NSObject

- (UIViewController *)showAuthScreenWithSuccess:(GoogleOAuthSuccessBlock)success
                                        failure:(GoogleOAuthFailureBlock)failure;

@end
