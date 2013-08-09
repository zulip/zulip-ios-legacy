//
//  PreferencesWrapper.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/9/13.
//
//

#import <Foundation/Foundation.h>

/**
 Wraps NSUserDefaults to be user-specific, similar to how we have
 specific sqlite files for each user/domain. Since NSUserDefaults
 doesn't have any built-in sandboxing, we fake it by prepending each
 key
 */
@interface PreferencesWrapper : NSObject

+ (PreferencesWrapper *)sharedInstance;

- (void)removeKey:(NSString *)key;

- (void)setPointer:(long)pointer;
- (long)pointer;

- (void)setPersistentQueue:(NSDictionary *)queue forName:(NSString *)queueName;
- (NSDictionary *)persistentQueueWithName:(NSString *)name;

- (void)setFullName:(NSString *)name;
- (NSString *)fullName;

@property (nonatomic, retain) NSString *domain;

@end
