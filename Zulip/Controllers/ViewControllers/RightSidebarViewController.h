//
//  RightSidebarViewController.h
//  Zulip
//
//  Created by Michael Walker on 12/27/13.
//
//

#import <UIKit/UIKit.h>

@interface RightSidebarViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) UITableView *tableView;


@end
