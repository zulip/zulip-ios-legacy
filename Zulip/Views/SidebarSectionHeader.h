//
//  SidebarStreamsHeader.h
//  Zulip
//
//  Created by Leonardo Franchi on 8/2/13.
//
//

#import <UIKit/UIKit.h>

@interface SidebarSectionHeader : UIViewController
@property (nonatomic, retain) IBOutlet UILabel *label;

@property (nonatomic, strong) NSString *sectionTitle;

- (instancetype)initWithTitle:(NSString *)title;
@end
