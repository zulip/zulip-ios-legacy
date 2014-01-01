//
//  PresenceManager.h
//  Zulip
//
//  Created by Leonardo Franchi on 12/31/13.
//
//

#import <Foundation/Foundation.h>

// PresenceManager updates the Zulip server periodially when in the foreground, with presence information
// It also receives and handles the realm's presence information and inserts it into Core Data
@interface PresenceManager : NSObject

@end
