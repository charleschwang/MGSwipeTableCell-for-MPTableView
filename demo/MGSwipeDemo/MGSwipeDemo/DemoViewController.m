/*
 * MGSwipeTableCell is licensed under MIT license. See LICENSE.md file for more information.
 * Copyright (c) 2014 Imanol Fernandez @MortimerGoro
 */

#import "DemoViewController.h"
#import "TestData.h"
#import "MGSwipeButton.h"

#define TEST_USE_MG_DELEGATE 1

@implementation DemoViewController
{
    NSMutableArray * tests;
    UIBarButtonItem * prevButton;
    UIImageView * background; //used for transparency test
    BOOL allowMultipleSwipe;
}


-(void) cancelTableEditClick: (id) sender
{
    self.navigationItem.rightBarButtonItem = prevButton;
    prevButton = nil;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    if (buttonIndex == 1) {
        tests = [TestData data];
        [_tableView reloadData];
    }
    else if (buttonIndex == 2) {
        prevButton = self.navigationItem.rightBarButtonItem;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleDone target:self action:@selector(cancelTableEditClick:)];
    }
    else if (buttonIndex == 3) {
        [_tableView reloadData];
    }
    else if (buttonIndex == 4) {
        if (background) {
            [background removeFromSuperview];
            _tableView.backgroundColor = [UIColor whiteColor];
        }
        else {
            background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"background.jpg"]];
            background.frame = self.view.bounds;
            background.contentMode = UIViewContentModeScaleToFill;
            background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.view insertSubview:background belowSubview:_tableView];
            _tableView.backgroundColor = [UIColor clearColor];
        }
        [_tableView reloadData];
    }
    else if (buttonIndex == 5) {
        allowMultipleSwipe = !allowMultipleSwipe;
        [_tableView reloadData];
    }
    else {
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"autolayout_test" bundle:nil];
        DemoViewController *vc = [sb instantiateInitialViewController];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

-(void) actionClick: (id) sender
{
    
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle:@"Select action" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles: nil];
    [sheet addButtonWithTitle:@"Reload test"];
    [sheet addButtonWithTitle:@"Multiselect test"];
    [sheet addButtonWithTitle:@"Change accessory button"];
    [sheet addButtonWithTitle:@"Transparency test"];
    [sheet addButtonWithTitle: allowMultipleSwipe ?  @"Single Swipe" : @"Multiple Swipe"];
    [sheet showInView:self.view];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    tests = [TestData data];
    self.title = @"MGSwipeCell";
    
    _tableView = [[MPTableView alloc] initWithFrame:self.view.bounds style:MPTableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
    
    self.navigationItem.rightBarButtonItem =  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionClick:)];
}


-(NSArray *) createLeftButtons: (int) number
{
    NSMutableArray * result = [NSMutableArray array];
    UIColor * colors[3] = {[UIColor greenColor],
        [UIColor colorWithRed:0 green:0x99/255.0 blue:0xcc/255.0 alpha:1.0],
        [UIColor colorWithRed:0.59 green:0.29 blue:0.08 alpha:1.0]};
    UIImage * icons[3] = {[UIImage imageNamed:@"check.png"], [UIImage imageNamed:@"fav.png"], [UIImage imageNamed:@"menu.png"]};
    for (int i = 0; i < number; ++i)
    {
        MGSwipeButton * button = [MGSwipeButton buttonWithTitle:@"" icon:icons[i] backgroundColor:colors[i] padding:15 callback:^BOOL(MGSwipeTableCell * sender){
            NSLog(@"Convenience callback received (left).");
            return YES;
        }];
        [result addObject:button];
    }
    return result;
}


-(NSArray *) createRightButtons: (int) number
{
    NSMutableArray * result = [NSMutableArray array];
    NSString* titles[2] = {@"Delete", @"More"};
    UIColor * colors[2] = {[UIColor redColor], [UIColor lightGrayColor]};
    for (int i = 0; i < number; ++i)
    {
        MGSwipeButton * button = [MGSwipeButton buttonWithTitle:titles[i] backgroundColor:colors[i] callback:^BOOL(MGSwipeTableCell * sender){
            NSLog(@"Convenience callback received (right).");
            BOOL autoHide = i != 0;
            return autoHide; //Don't autohide in delete button to improve delete expansion animation
        }];
        [result addObject:button];
    }
    return result;
}



- (NSUInteger)MPTableView:(MPTableView *)tableView numberOfRowsInSection:(NSUInteger)section;
{
    return tests.count;
}

- (MPTableViewCell *)MPTableView:(MPTableView *)tableView cellForRowAtIndexPath:(MPIndexPath *)indexPath
{
    MGSwipeTableCell * cell;
    static NSString * reuseIdentifier = @"programmaticCell";
    cell = [_tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    UILabel * textLabel, *detailTextLabel;
    if (!cell) {
        cell = [[MGSwipeTableCell alloc] initWithReuseIdentifier:reuseIdentifier];
        textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width / 3 * 2, 60)];
        textLabel.font = [UIFont systemFontOfSize:16];
        textLabel.tag = 250;
        [cell addSubview:textLabel];
        
        detailTextLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLabel.frame.size.width, 0, tableView.frame.size.width / 3, 60)];
        detailTextLabel.font = [UIFont systemFontOfSize:12];
        detailTextLabel.tag = 251;
        [cell addSubview:detailTextLabel];
    } else {
        textLabel = [cell viewWithTag:250];
        detailTextLabel = [cell viewWithTag:251];
    }
    
    TestData * data = [tests objectAtIndex:indexPath.row];
    
    textLabel.text = data.title;
    detailTextLabel.text = data.detailTitle;
    cell.delegate = self;
    cell.allowsMultipleSwipe = allowMultipleSwipe;
    
    if (background) { //transparency test
        cell.selectionColor = [[UIColor yellowColor] colorWithAlphaComponent:0.3];
        cell.backgroundColor = [UIColor clearColor];
        cell.swipeBackgroundColor = [UIColor clearColor];
        textLabel.textColor = [UIColor yellowColor];
        detailTextLabel.textColor = [UIColor yellowColor];
    }

#if !TEST_USE_MG_DELEGATE
    cell.leftSwipeSettings.transition = data.transition;
    cell.rightSwipeSettings.transition = data.transition;
    cell.leftExpansion.buttonIndex = data.leftExpandableIndex;
    cell.leftExpansion.fillOnTrigger = NO;
    cell.rightExpansion.buttonIndex = data.rightExpandableIndex;
    cell.rightExpansion.fillOnTrigger = YES;
    cell.leftButtons = [self createLeftButtons:data.leftButtonsCount];
    cell.rightButtons = [self createRightButtons:data.rightButtonsCount];
#endif
    
    return cell;
}

#if TEST_USE_MG_DELEGATE
-(NSArray*) swipeTableCell:(MGSwipeTableCell*) cell swipeButtonsForDirection:(MGSwipeDirection)direction
             swipeSettings:(MGSwipeSettings*) swipeSettings expansionSettings:(MGSwipeExpansionSettings*) expansionSettings;
{
    TestData * data = [tests objectAtIndex:[_tableView indexPathForCell:cell].row];
    swipeSettings.transition = data.transition;
    
    if (direction == MGSwipeDirectionLeftToRight) {
        expansionSettings.buttonIndex = data.leftExpandableIndex;
        expansionSettings.fillOnTrigger = NO;
        return [self createLeftButtons:data.leftButtonsCount];
    }
    else {
        expansionSettings.buttonIndex = data.rightExpandableIndex;
        expansionSettings.fillOnTrigger = YES;
        return [self createRightButtons:data.rightButtonsCount];
    }
}
#endif


- (CGFloat)MPTableView:(MPTableView *)tableView heightForIndexPath:(MPIndexPath *)indexPath
{
    return 60;
}

-(BOOL) swipeTableCell:(MGSwipeTableCell*) cell tappedButtonAtIndex:(NSInteger) index direction:(MGSwipeDirection)direction fromExpansion:(BOOL) fromExpansion
{
    NSLog(@"Delegate: button tapped, %@ position, index %d, from Expansion: %@",
          direction == MGSwipeDirectionLeftToRight ? @"left" : @"right", (int)index, fromExpansion ? @"YES" : @"NO");
    
    if (direction == MGSwipeDirectionRightToLeft && index == 0) {
        //delete button
        MPIndexPath * path = [_tableView indexPathForCell:cell];
        [tests removeObjectAtIndex:path.row];
        [_tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationLeft];
        return NO; //Don't autohide to improve delete expansion animation
    }
    
    return YES;
}

- (BOOL) swipeTableCell:(MGSwipeTableCell *)cell shouldHideSwipeOnTap:(CGPoint)point {
    return NO;
}

@end
