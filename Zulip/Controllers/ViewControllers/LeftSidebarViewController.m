//
//  LeftSidebarViewController.m
//  Zulip
//
//  Created by Leonardo Franchi on 8/7/13.
//
//
#import "LeftSidebarViewController.h"
#import "ZulipAPIController.h"
#import "ZulipAppDelegate.h"
#import "ZUser.h"
#import "UnreadManager.h"

// Various cells
#import "SidebarStreamCell.h"
#import "SidebarSectionHeader.h"

#import "UIViewController+JASidePanel.h"
#import "UIImageView+AFNetworking.h"
#import "UIColor+HexColor.h"

#import <QuartzCore/QuartzCore.h>

@interface LeftSidebarViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, retain) NSFetchedResultsController *streamController;
@property (nonatomic, retain) SidebarSectionHeader *sidebarStreamsHeader;

@property (nonatomic, retain) NSString *avatar_url;

@end

@implementation LeftSidebarViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
        self.streamController = 0;
        self.sidebarStreamsHeader = 0;

        self.avatar_url = 0;

        [[NSNotificationCenter defaultCenter] addObserverForName:ZUnreadCountChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [self handleMessageCountChangedNotification:[[note userInfo] objectForKey:ZUnreadCountChangeNotificationData]];
        }];

        // Reset on logout/login
        [[NSNotificationCenter defaultCenter] addObserverForName:kLogoutNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self reset];
                                                      }];

        [[NSNotificationCenter defaultCenter] addObserverForName:kLoginNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self reset];
                                                      }];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithHexString:@"#F4F5F4" defaultColor:[UIColor whiteColor]];

    self.sidebarStreamsHeader = [[SidebarSectionHeader alloc] initWithTitle:@"Streams"];

    // On iOS 7 with translucent status bars, we move the top down so it's not obscured
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        UIEdgeInsets insets = UIEdgeInsetsMake(15.0, 0.0, 0.0, 0.0);
        self.tableView.contentInset = insets;
    }

    [self setupFetchedResultsController];
}

- (void)setupFetchedResultsController
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];

    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];

    // TODO consider doing the fetching in the background? Requires a per-thread Managed Object Context
    self.streamController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                managedObjectContext:[appDelegate managedObjectContext]
                                                                  sectionNameKeyPath:nil
                                                                           cacheName:nil];

    self.streamController.delegate = self;

    NSError *error = nil;
    [self.streamController performFetch:&error];
    if (error) {
        NSLog(@"Failed to fetch Subscriptions from core data: %@ %@", [error localizedDescription], [error userInfo]);
    }

    // Fetch user's gravatar if it's there
    ZUser *user =[[ZulipAPIController sharedInstance] getPersonFromCoreDataWithEmail:[[ZulipAPIController sharedInstance] email]];
    if (user)
    {
        self.avatar_url = user.avatar_url;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.streamController = 0;
}

- (void)reset
{
    self.streamController = 0;
    [self setupFetchedResultsController];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // 4 sections:
    // Name
    // Home/Private
    // Stream list
    // Logout
    return 4;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 1; // Name
        case 1:
            return 4; // Misc Narrows
        case 2:
        {
            // Streams
            NSArray *sections = self.streamController.sections;
            if ([sections count] > 0)
                return [[sections objectAtIndex:0] numberOfObjects];
            else
                return 0;
        }
        case 3:
            return 1; // Logout (Settings?)
        default:
            break;
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1 ||
        indexPath.section == 2) {
        SidebarStreamCell *sidebarCell = (SidebarStreamCell *)cell;
        [sidebarCell setBackgroundIfCurrent];
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    switch (indexPath.section) {
        case 0:
        {
            // Name
            cell = [self loadTableViewCell:@"UserNameCell"];
            break;
        }
        case 1:
        {
            // Misc narrows
            cell = [self loadSidebarStreamCell:@"MiscNarrow"];
            break;
        }
        case 2:
        {
            // Streams
            cell = [self loadSidebarStreamCell:@"MiscNarrow"];
            break;
        }
        case 3:
        {
            // Logout (Settings?)
            cell = [self loadTableViewCell:@"LogoutCell"];
            break;
        }
        default:
            NSLog(@"MISSING TABLE VIEW CELL!? %@", indexPath);
            break;
    }
    [self configureCell:cell atIndexPath:indexPath];

    return cell;
}


- (SidebarStreamCell *)loadSidebarStreamCell:(NSString *)cellIdentifier
{
    SidebarStreamCell *my_cell = (SidebarStreamCell *)[self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (my_cell == nil) {
        NSArray *loaded  = [[NSBundle mainBundle] loadNibNamed:@"SidebarStreamCell" owner:self options:nil];
        my_cell = (SidebarStreamCell *)[loaded objectAtIndex:0];
    }
    return my_cell;
}

- (UITableViewCell *)loadTableViewCell:(NSString *)cellIdentifier
{
    UITableViewCell *cell = (UITableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = YES;
    }
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
        {
            cell.textLabel.text = [[ZulipAPIController sharedInstance] fullName];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
            cell.opaque = NO;
            cell.backgroundColor = [UIColor clearColor];

            if (self.avatar_url) {
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.avatar_url]];
                [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

                // Weak reference to UIImageView to avoid retain cycle with success block
                __weak UIImageView *imageView = cell.imageView;

                UIImage *placeholder = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"my_avatar_placeholder" ofType:@"png"]];
                [cell.imageView setImageWithURLRequest:request placeholderImage:placeholder success:^(NSURLRequest *r, NSHTTPURLResponse *resp, UIImage *img) {
                    imageView.image = img;
                    // Mask to get rounded corners
                    CALayer *layer = imageView.layer;
                    [layer setMasksToBounds:YES];
                    [layer setCornerRadius:20.0f];
                } failure:nil];

            }
            break;
        }
        case 1:
        {
            // Misc narrows
            SidebarStreamCell *my_cell = (SidebarStreamCell *)cell;
            switch (indexPath.row) {
                case 0:
                    my_cell.shortcut = HOME;
                    break;
                case 1:
                    my_cell.shortcut = PRIVATE_MESSAGES;
                    break;
                case 2:
                    my_cell.shortcut = STARRED;
                    break;
                case 3:
                    my_cell.shortcut = AT_MENTIONS;
                    break;
                default:
                    break;
            }
            break;
        }
        case 2:
        {
            // Streams
            SidebarStreamCell *my_cell = (SidebarStreamCell *)cell;
            NSIndexPath *cdIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
            ZSubscription *stream = (ZSubscription *)[self.streamController objectAtIndexPath:cdIndexPath];
            [my_cell setStream:stream];
            break;
        }
        case 3:
        {
            // Logout (Settings?)
            cell.textLabel.text = @"Logout";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
            break;
        }
        default:
            NSLog(@"MISSING TABLE VIEW CELL!? %@", indexPath);
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1 ||
        indexPath.section == 2) {
        SidebarStreamCell *cell = (SidebarStreamCell *)[self tableView:self.tableView cellForRowAtIndexPath:indexPath];
        return cell.bounds.size.height;
    } else {
        UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
        return cell.bounds.size.height;

    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Stream section has a "Streams.." header, no other sections do.
    if (section == 2) {
        return [self.sidebarStreamsHeader.view bounds].size.height;
    } else {
        return 0;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 2) {
        return self.sidebarStreamsHeader.view;
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Narrow to what the user selected
    if (indexPath.section == 1 ||
        indexPath.section == 2) {
        SidebarStreamCell *cell = (SidebarStreamCell *)[self.tableView cellForRowAtIndexPath:indexPath];

        ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
        if (cell.shortcut == HOME) {
            [appDelegate clearNarrowWithAnimation:YES];
        } else {
            if (cell.narrow) {
                [appDelegate narrowWithOperators:cell.narrow];
            } else {
                NSLog(@"ERROR: Trying to narrow but have a null NarrowOperators!!");
            }
        }
    } else if (indexPath.section == 3) {
        // Logout
        [[ZulipAPIController sharedInstance] logout];

        LoginViewController *loginView = [[LoginViewController alloc] initWithNibName:@"LoginViewController"
                                                                               bundle:nil];
        [self.findSidePanelController toggleLeftPanel:self];

        ZulipAppDelegate *delegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
        [[delegate navController] pushViewController:loginView animated:YES];
    }

    // Update selected state of all rows
    for (int i = 0; i < [self tableView:self.tableView numberOfRowsInSection:1]; i++) {
        SidebarStreamCell *cell = (SidebarStreamCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1]];
        [cell setBackgroundIfCurrent];
    }
    for (int i = 0; i < [self tableView:self.tableView numberOfRowsInSection:2]; i++) {
        SidebarStreamCell *cell = (SidebarStreamCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:2]];
        if (!cell) {
            continue;
        }
        [cell setBackgroundIfCurrent];
    }
}


#pragma mark - NSFetchedResultsControllerDelegate

// Standard delegate methods, except we replace the section of 0 with
// a section of 2
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {

    UITableView *tableView = self.tableView;


    NSIndexPath *sectionFixedPath = [NSIndexPath indexPathForRow:newIndexPath.row inSection:2];
    switch(type) {

        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:sectionFixedPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:sectionFixedPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:sectionFixedPath]
                    atIndexPath:sectionFixedPath];
            break;

        case NSFetchedResultsChangeMove:
        {
            NSIndexPath *oldSectionFixedPath = [NSIndexPath indexPathForRow:indexPath.row inSection:2];

            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:oldSectionFixedPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:sectionFixedPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

#pragma mark - NotificationCenter

- (void)handleMessageCountChangedNotification:(NSDictionary *)unreadCounts
{
    // Only update visible cells as other cells will get configureCell: called
    // when they become visible
    for (UITableViewCell *cell in [self.tableView visibleCells]) {
        if(cell && [cell isKindOfClass:[SidebarStreamCell class]]) {
            SidebarStreamCell *streamCell = (SidebarStreamCell *)cell;
            [streamCell setUnreadCount:unreadCounts];
        }
    }
}

@end
