//
//  MessageComposing.h
//  Zulip
//
//  Created by Michael Walker on 1/21/14.
//
//

#import <Foundation/Foundation.h>

@protocol MessageComposing <NSObject>

- (void)showComposeViewForUser:(ZUser *)user;

@end
