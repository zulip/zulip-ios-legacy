//
//  SidebarSectionHeader.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/2/13.
//
//

#import "SidebarSectionHeader.h"

#import <QuartzCore/QuartzCore.h>

@implementation SidebarSectionHeader

- (instancetype)initWithTitle:(NSString *)title {
    if (self = [self init]) {
        self.sectionTitle = title;
    }

    return self;
}

- (id)init
{
    self = [super initWithNibName:@"SidebarSectionHeader" bundle:[NSBundle mainBundle]];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Draw a nice bottom border for the section header
    UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) - 2.0f, CGRectGetWidth(self.view.bounds), 0.5f)];
    bottomBorder.backgroundColor = [UIColor colorWithRed:(200.0f/255.0f) green:(200.0f/255.0f) blue:(200.0f/255.0f) alpha:1.0f];
    
    bottomBorder.layer.shadowColor = [UIColor darkGrayColor].CGColor;
    bottomBorder.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
    bottomBorder.layer.shadowOpacity = 0.1f;

    [self.view addSubview:bottomBorder];

    // On iOS 7 we keep the background translucent
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        self.view.backgroundColor = [UIColor clearColor];
    }

    self.label.text = self.sectionTitle;
}

- (void)setSectionTitle:(NSString *)sectionTitle {
    _sectionTitle = sectionTitle;
    self.label.text = _sectionTitle;
}

@end
