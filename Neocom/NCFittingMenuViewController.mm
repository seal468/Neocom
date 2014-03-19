//
//  NCFittingMenuViewController.m
//  Neocom
//
//  Created by Shimanski Artem on 27.01.14.
//  Copyright (c) 2014 Artem Shimanski. All rights reserved.
//

#import "NCFittingMenuViewController.h"
#import "NCTableViewCell.h"
#import "NCDatabaseTypePickerViewController.h"
#import "UIViewController+Neocom.h"
#import "NCStorage.h"
#import "NCShipFit.h"
#import "NCPOSFit.h"
#import "NSArray+Neocom.h"
#import "NCFittingShipViewController.h"
#import "NCFittingPOSViewController.h"
#import "NCFittingCharacterPickerViewController.h"

@interface NCFittingMenuViewController ()
@property (nonatomic, strong, readwrite) NCDatabaseTypePickerViewController* typePickerViewController;
@property (nonatomic, strong) NSMutableArray* sections;
@end

@implementation NCFittingMenuViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.refreshControl = nil;
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	// Do any additional setup after loading the view.
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"NCFittingShipViewController"]) {
		NCFittingShipViewController* destinationViewController = segue.destinationViewController;
		destinationViewController.fit = sender;
	}
	else if ([segue.identifier isEqualToString:@"NCFittingPOSViewController"]) {
		NCFittingPOSViewController* destinationViewController = segue.destinationViewController;
		destinationViewController.fit = sender;
	}
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sections.count + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? 4 : [(NSArray*) self.sections[section - 1] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		NSString *CellIdentifier = [NSString stringWithFormat:@"MenuItem%ldCell", (long)indexPath.row];
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		return cell;
	}
	else {
		NCTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
		NCLoadout* loadout = self.sections[indexPath.section - 1][indexPath.row];
		cell.titleLabel.text = loadout.type.typeName;
		cell.subtitleLabel.text = loadout.name;
		cell.iconView.image = [UIImage imageNamed:loadout.type.typeSmallImageName];
		return cell;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return nil;
	else {
		NSArray* rows = self.sections[section - 1];
		if (rows.count > 0)
			return [rows[0] valueForKeyPath:@"type.group.groupName"];
		else
			return nil;
	}
}

- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 0 ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSMutableArray* array = self.sections[indexPath.section - 1];
		NCLoadout* loadout = array[indexPath.row];
		[loadout.managedObjectContext performBlockAndWait:^{
			[loadout.managedObjectContext deleteObject:loadout];
			[[NCStorage sharedStorage] saveContext];
		}];
		
		if (array.count == 1) {
			[self.sections removeObjectAtIndex:indexPath.section - 1];
			[tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationMiddle];
		}
		else {
			[array removeObjectAtIndex:indexPath.row];
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
		}
	}
}

#pragma mark - Table view delegate

- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 41;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0)
		return 41;
	else {
		UITableViewCell* cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
		cell.bounds = CGRectMake(0, 0, CGRectGetWidth(tableView.bounds), CGRectGetHeight(cell.bounds));
		[cell setNeedsLayout];
		[cell layoutIfNeeded];
		return [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height + 1.0;
	}
}

- (BOOL) tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section != 0;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	if (indexPath.section == 0) {
		if (indexPath.row == 2) {
			self.typePickerViewController.title = NSLocalizedString(@"Ships", nil);
			[self.typePickerViewController presentWithConditions:@[@"invGroups.groupID = invTypes.groupID", @"invGroups.categoryID = 6"]
												inViewController:self
														fromRect:cell.bounds
														  inView:cell
														animated:YES
											   completionHandler:^(EVEDBInvType *type) {
												   NCShipFit* fit = [[NCShipFit alloc] initWithType:type];
												   NCStorage* storage = [NCStorage sharedStorage];
												   fit.loadout = [[NCLoadout alloc] initWithEntity:[NSEntityDescription entityForName:@"Loadout" inManagedObjectContext:storage.managedObjectContext] insertIntoManagedObjectContext:storage.managedObjectContext];
												   fit.loadout.data = [[NCLoadoutData alloc] initWithEntity:[NSEntityDescription entityForName:@"LoadoutData" inManagedObjectContext:storage.managedObjectContext] insertIntoManagedObjectContext:storage.managedObjectContext];
												   
												   [self performSegueWithIdentifier:@"NCFittingShipViewController" sender:fit];
												   [self dismissAnimated];
											   }];
		}
		else if (indexPath.row == 3) {
			self.typePickerViewController.title = NSLocalizedString(@"Control Towers", nil);
			[self.typePickerViewController presentWithConditions:@[@"invTypes.marketGroupID = 478"]
												inViewController:self
														fromRect:cell.bounds
														  inView:cell
														animated:YES
											   completionHandler:^(EVEDBInvType *type) {
												   NCPOSFit* fit = [[NCPOSFit alloc] initWithType:type];
												   NCStorage* storage = [NCStorage sharedStorage];
												   fit.loadout = [[NCLoadout alloc] initWithEntity:[NSEntityDescription entityForName:@"Loadout" inManagedObjectContext:storage.managedObjectContext] insertIntoManagedObjectContext:storage.managedObjectContext];
												   fit.loadout.data = [[NCLoadoutData alloc] initWithEntity:[NSEntityDescription entityForName:@"LoadoutData" inManagedObjectContext:storage.managedObjectContext] insertIntoManagedObjectContext:storage.managedObjectContext];
												   
												   [self performSegueWithIdentifier:@"NCFittingPOSViewController" sender:fit];
												   [self dismissAnimated];
											   }];
		}
	}
	else {
		NCLoadout* loadout = self.sections[indexPath.section - 1][indexPath.row];
		if (loadout.category == NCLoadoutCategoryShip) {
			NCShipFit* fit = [[NCShipFit alloc] initWithLoadout:loadout];
			[self performSegueWithIdentifier:@"NCFittingShipViewController" sender:fit];
		}
		else {
			NCPOSFit* fit = [[NCPOSFit alloc] initWithLoadout:loadout];
			[self performSegueWithIdentifier:@"NCFittingPOSViewController" sender:fit];
		}
	}
}

#pragma mark - NCTableViewController

- (NSString*) recordID {
	return nil;
}

#pragma mark - Private

- (void) reload {
	NSMutableArray* sections = [NSMutableArray new];
	[[self taskManager] addTaskWithIndentifier:NCTaskManagerIdentifierAuto
										 title:NCTaskManagerDefaultTitle
										 block:^(NCTask *task) {
											 NCStorage* storage = [NCStorage sharedStorage];
											 [storage.managedObjectContext performBlockAndWait:^{
												 NSArray* shipLoadouts = [[NCLoadout shipLoadouts] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"type.typeName" ascending:YES]]];
												 task.progress = 0.25;
												 
												 for (NSArray* array in [shipLoadouts arrayGroupedByKey:@"type.groupID"])
													 [sections addObject:[array mutableCopy]];
												 
												 task.progress = 0.5;
												 [sections sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
													 NCLoadout* a = [obj1 objectAtIndex:0];
													 NCLoadout* b = [obj2 objectAtIndex:0];
													 return [a.type.group.groupName compare:b.type.group.groupName];
												 }];
												 
												 task.progress = 0.75;
												 
												 NSArray* posLoadouts = [[NCLoadout posLoadouts] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"type.typeName" ascending:YES]]];
												 if (posLoadouts.count > 0)
													 [sections addObject:[posLoadouts mutableCopy]];
												 
												 task.progress = 1.0;
											 }];
										 }
							 completionHandler:^(NCTask *task) {
								 self.sections = sections;
								 [self.tableView reloadData];
								 
							 }];
}

- (NCDatabaseTypePickerViewController*) typePickerViewController {
	if (!_typePickerViewController) {
		_typePickerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"NCDatabaseTypePickerViewController"];
	}
	return _typePickerViewController;
}

- (id) identifierForSection:(NSInteger)section {
	if (section > 0) {
		NSArray* rows = self.sections[section - 1];
		if (rows.count > 0)
			return [rows[0] valueForKeyPath:@"type.group.groupID"];
	}
	return nil;
}

@end
