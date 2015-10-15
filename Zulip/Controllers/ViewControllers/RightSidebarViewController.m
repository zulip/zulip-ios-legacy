//
//  RightSidebarViewController.m
//  Zulip
//
//  Created by Michael Walker on 12/27/13.
//
//

#import "RightSidebarViewController.h"

#import "ZulipAPIController.h"
#import "ZulipAppDelegate.h"
#import "ZUser.h"
#import "ZUserPresence.h"
#import "UnreadManager.h"
#import "MessageComposing.h"

// Various cells
#import "SidebarUserCell.h"
#import "SidebarSectionHeader.h"

#import "JASidePanelController.h"
#import "UIViewController+JASidePanel.h"
#import "UIColor+HexColor.h"

#import <QuartzCore/QuartzCore.h>

const CGFloat RightSidebarViewControllerUserCellHeight = 26.f;
const CGFloat RightSidebarViewControllerStatusBarOffset = 15.f;

@interface RightSidebarViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSArray *userPresences;

@property (nonatomic, retain) NSFetchedResultsController *userController;
@property (nonatomic, retain) SidebarSectionHeader *sidebarUsersHeader;

@end

@implementation RightSidebarViewController

- (id)init
{
    if (self = [super init]) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        [self.view addSubview:self.tableView];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;

        [self.tableView registerNib:[UINib nibWithNibName:@"SidebarUserCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:NSStringFromClass([SidebarUserCell class])];

        [[NSNotificationCenter defaultCenter] addObserverForName:ZUnreadCountChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self handleMessageCountChangedNotification:[[note userInfo] objectForKey:ZUnreadCountChangeNotificationData]];
                                                      }];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setLeftMargin];
    self.view.backgroundColor = [UIColor colorWithHexString:@"#F4F5F4" defaultColor:[UIColor whiteColor]];
    self.tableView.backgroundColor = self.view.backgroundColor;

    self.sidebarUsersHeader = [[SidebarSectionHeader alloc] initWithTitle:@"Users"];

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self setupFetchedResultsController];

}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self setLeftMargin];
}

- (void)setupFetchedResultsController
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZUserPresence"];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"status" ascending:YES]];

    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];

    self.userController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                managedObjectContext:[appDelegate managedObjectContext]
                                                                  sectionNameKeyPath:nil
                                                                         cacheName:nil];

    self.userController.delegate = self;

    NSError *error = nil;
    [self.userController performFetch:&error];
    if (error) {
        NSLog(@"Failed to fetch Users from core data: %@ %@", [error localizedDescription], [error userInfo]);
    }

    [self calculatePresences];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.userController = nil;
}

#pragma mark - Private methods
- (void)calculatePresences {
    NSDictionary *sets = @{
                           ZUserPresenceStatusActive: [[NSMutableOrderedSet alloc] init],
                           ZUserPresenceStatusIdle: [[NSMutableOrderedSet alloc] init],
                           ZUserPresenceStatusOffline: [[NSMutableOrderedSet alloc] init]
                           };

    for (ZUserPresence *presence in self.userController.fetchedObjects) {
        [sets[presence.currentStatus] addObject:presence];
    }

    NSSortDescriptor *alphabeticalSort = [NSSortDescriptor sortDescriptorWithKey:@"user.full_name" ascending:YES];

    NSArray *finalList = [NSArray array];
    for (NSString *key in @[ZUserPresenceStatusActive, ZUserPresenceStatusIdle, ZUserPresenceStatusOffline]) {
        NSArray *sorted = [sets[key] sortedArrayUsingDescriptors:@[alphabeticalSort]];
        finalList = [finalList arrayByAddingObjectsFromArray:sorted];
    }

    self.userPresences = finalList;
}

#pragma mark - UITableViewDataSource


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.userPresences.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SidebarUserCell *cell = [self.tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SidebarUserCell class])];

    ZUserPresence *presence = self.userPresences[indexPath.row];
    cell.user = presence.user;
    cell.status = presence.currentStatus;

    return cell;
}


- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return RightSidebarViewControllerUserCellHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return CGRectGetHeight(self.sidebarUsersHeader.view.frame);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return self.sidebarUsersHeader.view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SidebarUserCell *cell = (SidebarUserCell *)[self.tableView cellForRowAtIndexPath:indexPath];

    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    NarrowOperators *operators = [[NarrowOperators alloc] init];
    [operators addUserNarrow:cell.user.email];
    [appDelegate narrowWithOperators:operators];

    [self.findSidePanelController toggleRightPanel:self];

    // Weird things happen if the compose view is shown before the view controller has loaded.
    // Ideally, this would be solved by giving [JASidePanelController toggleRightPanel] a completion block.
    double delayInSeconds = 1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        id<MessageComposing> centerController = (id<MessageComposing>)[(UINavigationController *)self.findSidePanelController.centerPanel visibleViewController];
        if ([centerController conformsToProtocol:@protocol(MessageComposing)]) {
            [centerController showComposeViewForUser:cell.user];
        }
    });
}


#pragma mark - NSFetchedResultsControllerDelegate

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    [self calculatePresences];
    [self.tableView reloadData];
}

#pragma mark - NotificationCenter

- (void)handleMessageCountChangedNotification:(NSDictionary *)unreadCounts
{
    for (UITableViewCell *cell in [self.tableView visibleCells]) {
        if(cell && [cell isKindOfClass:[SidebarUserCell class]]) {
            SidebarUserCell *userCell = (SidebarUserCell *)cell;
            [userCell calculateUnreadCount];
        }
    }
}

#pragma mark - Private
- (void)setLeftMargin {
    CGRect frame = self.view.bounds;
    frame.origin.x = self.view.frame.size.width - self.findSidePanelController.rightVisibleWidth + 10;

    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        frame.origin.y = RightSidebarViewControllerStatusBarOffset;
    }
    self.tableView.frame = frame;
}

@end
