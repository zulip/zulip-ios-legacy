//
//  PreferencesWrapper.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/9/13.
//
//

#import "PreferencesWrapper.h"

#import "ZulipAPIController.h"

@implementation PreferencesWrapper


static dispatch_once_t *onceTokenPointer;

- (id)init
{
    self = [super init];
    if (self) {
        self.domain = @"";
    }
    return self;
}

- (void)removeKey:(NSString *)key
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self keyWithPrefix:key]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)fullName
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:[self keyWithPrefix:@"fullName"]];
}

- (void)setFullName:(NSString *)fullName
{
    [[NSUserDefaults standardUserDefaults] setObject:fullName forKey:[self keyWithPrefix:@"fullName"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (long)pointer
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:[self keyWithPrefix:@"pointer"]] longValue];
}

- (void)setPointer:(long)pointer
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithLong:pointer] forKey:[self keyWithPrefix:@"pointer"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)persistentQueueWithName:(NSString *)name
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:[self keyWithPrefix:name]];
}

- (void)setPersistentQueue:(NSDictionary *)queue forName:(NSString *)queueName
{
    [[NSUserDefaults standardUserDefaults] setObject:queue forKey:[self keyWithPrefix:queueName]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)keyWithPrefix:(NSString *)key
{
    return [NSString stringWithFormat:@"%@-%@", self.domain, key];
}

// Singleton
+ (PreferencesWrapper *)sharedInstance {
    static PreferencesWrapper *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    onceTokenPointer = &onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[PreferencesWrapper alloc] init];
    });

    return _sharedInstance;
}

@end
