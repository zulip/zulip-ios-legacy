//
//  RenderedMarkdownMunger.h
//  Zulip
//
//  Created by Humbug on 8/8/13.
//
//

#import <Foundation/Foundation.h>
#import "RawMessage.h"

@interface RenderedMarkdownMunger : NSObject

+ (void)mungeThis:(RawMessage*)message;
+ (NSString *)emojiShortNameFromUnicode:(NSString *)unicode;

@end
