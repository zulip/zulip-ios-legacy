//
//  StreamsSidebarController.m
//  Zulip
//
//  Created by Leonardo Franchi on 7/30/13.
//
//

#import "StreamsSidebarController.h"
#import "ZulipAPIController.h"
#import "ZulipAppDelegate.h"

// Various cells
#import "SidebarStreamCell.h"

@interface StreamsSidebarController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, retain) NSFetchedResultsController *streamController;
@property (nonatomic, retain) UIView *sidebarStreamsHeader;

@end

@implementation StreamsSidebarController

- (id)init
{
    id ret = [super init];

    return ret;
}

- (void)viewDidLoad
{
    CGRect bounds = CGRectMake(0, 0, 250, 568);
    self.tableView = [[UITableView alloc] initWithFrame:bounds style:UITableViewStylePlain];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"SidebarStreamsHeader" owner:self options:nil];
    self.sidebarStreamsHeader = [nib objectAtIndex:0];

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ZSubscription"];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];

    ZulipAppDelegate *appDelegate = (ZulipAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.streamController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                managedObjectContext:[appDelegate managedObjectContext]
                                                                  sectionNameKeyPath:nil
                                                                           cacheName:@"StreamSidebarCache"];
    self.streamController.delegate = self;

    NSError *error = nil;
    [self.streamController performFetch:&error];
    if (error) {
        NSLog(@"Failed to fetch Subscriptions from core data: %@ %@", [error localizedDescription], [error userInfo]);
    }
}

- (void)viewDidUnload
{
    self.streamController = 0;
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
            return 2; // Misc Narrows
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
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    switch (indexPath.section) {
        case 0:
        {
            // Name
            cell = (UITableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:@"UserNameCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UserNameCell"];
            }
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
            cell = (UITableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:@"LogoutCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LogoutCell"];
            }
            break;
        }
        default:
            NSLog(@"MISSING TABLE VIEW CELL!? %@", indexPath);
            break;
    }
    [self configureCell:cell atIndexPath:indexPath];

    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
        {
            cell.textLabel.text = [[ZulipAPIController sharedInstance] fullName];
            break;
        }
        case 1:
        {
            // Misc narrows
            SidebarStreamCell *my_cell = (SidebarStreamCell *)cell;
            switch (indexPath.row) {
                case 0:
                    my_cell.name.text = @"Home";
                    my_cell.shortcut = HOME;
                    break;
                case 1:
                    my_cell.name.text = @"Private Messages";
                    my_cell.shortcut = PRIVATE_MESSAGES;
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
            break;
        }
        default:
            NSLog(@"MISSING TABLE VIEW CELL!? %@", indexPath);
    }
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

//- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//
//}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Stream section has a "Streams.." header, no other sections do.
    if (section == 2) {
        return [self.sidebarStreamsHeader bounds].size.height;
    } else {
        return 0;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 2) {
        return self.sidebarStreamsHeader;
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
            if (cell.predicate) {
                [appDelegate narrow:cell.predicate];
            } else {
                NSLog(@"ERROR: Trying to narrow but have a nul predicate!!");
            }
        }
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

@end
