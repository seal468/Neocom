//
//  NCFittingShipModulesViewController.m
//  Neocom
//
//  Created by Артем Шиманский on 12.06.15.
//  Copyright (c) 2015 Artem Shimanski. All rights reserved.
//

#import "NCFittingShipModulesViewController.h"
#import "NCFittingShipViewController.h"
#import "UIView+Nib.h"
#import "NSString+Neocom.h"
#import <algorithm>
#import "NCTableViewCell.h"
#import "NCFittingShipModuleCell.h"
#import "NSNumberFormatter+Neocom.h"
#import "NCFittingSectionGenericHeaderView.h"
#import "UIActionSheet+Block.h"
#import "NCFittingSectionHiSlotHeaderView.h"

#define ActionButtonOffline NSLocalizedString(@"Put Offline", nil)
#define ActionButtonOnline NSLocalizedString(@"Put Online", nil)
#define ActionButtonOverheatOn NSLocalizedString(@"Enable Overheating", nil)
#define ActionButtonOverheatOff NSLocalizedString(@"Disable Overheating", nil)
#define ActionButtonActivate NSLocalizedString(@"Activate", nil)
#define ActionButtonDeactivate NSLocalizedString(@"Deactivate", nil)
#define ActionButtonAmmo NSLocalizedString(@"Ammo", nil)
#define ActionButtonCancel NSLocalizedString(@"Cancel", nil)
#define ActionButtonDelete NSLocalizedString(@"Delete", nil)
#define ActionButtonChangeState NSLocalizedString(@"Change State", nil)
#define ActionButtonUnloadAmmo NSLocalizedString(@"Unload Ammo", nil)
#define ActionButtonShowModuleInfo NSLocalizedString(@"Show Module Info", nil)
#define ActionButtonShowAmmoInfo NSLocalizedString(@"Show Ammo Info", nil)
#define ActionButtonSetTarget NSLocalizedString(@"Set Target", nil)
#define ActionButtonClearTarget NSLocalizedString(@"Clear Target", nil)
#define ActionButtonVariations NSLocalizedString(@"Variations", nil)
#define ActionButtonAllSimilarModules NSLocalizedString(@"All Similar Modules", nil)
#define ActionButtonAffectingSkills NSLocalizedString(@"Affecting Skills", nil)

@interface NCFittingShipModulesViewControllerRow : NSObject
@property (nonatomic, assign) int32_t typeID;
@property (nonatomic, assign) int32_t chargeID;
@property (nonatomic, assign) float chargeVolume;
@property (nonatomic, assign) float capacity;
@property (nonatomic, assign) float optimal;
@property (nonatomic, assign) float falloff;
@property (nonatomic, assign) float trackingSpeed;
@property (nonatomic, assign) float lifeTime;
@property (nonatomic, assign) float orbitRadius;
@property (nonatomic, strong) UIColor* trackingColor;
@property (nonatomic, strong) UIImage* stateImage;
@property (nonatomic, assign) BOOL hasTarget;
@end

@interface NCFittingShipModulesViewControllerSection : NSObject
@property (nonatomic, strong) NSArray* rows;
@property (nonatomic, assign) eufe::Module::Slot slot;
@property (nonatomic, assign) int numberOfSlots;
@end

@implementation NCFittingShipModulesViewControllerSection

@end

@interface NCFittingShipModulesViewController()
@property (nonatomic, assign) int usedTurretHardpoints;
@property (nonatomic, assign) int totalTurretHardpoints;
@property (nonatomic, assign) int usedMissileHardpoints;
@property (nonatomic, assign) int totalMissileHardpoints;
@property (nonatomic, strong) NCDBEveIcon* defaultTypeIcon;

@property (nonatomic, strong) NSArray* sections;

- (void) tableView:(UITableView *)tableView configureCell:(UITableViewCell*) tableViewCell forRowAtIndexPath:(NSIndexPath*) indexPath;

@end

@implementation NCFittingShipModulesViewController

- (void) viewDidLoad {
	[super viewDidLoad];
	self.defaultTypeIcon = [self.databaseManagedObjectContext defaultTypeIcon];
	
	[self.tableView registerNib:[UINib nibWithNibName:@"NCFittingSectionHiSlotHeaderView" bundle:nil] forHeaderFooterViewReuseIdentifier:@"NCFittingSectionHiSlotHeaderView"];
}

- (void) reload {
	NSMutableArray* sections = [NSMutableArray new];
	__block float usedTurretHardpoints;
	__block float totalTurretHardpoints;
	__block float usedMissileHardpoints;
	__block float totalMissileHardpoints;
	
	[self.controller.fit.engine performBlockAndWait:^{
		if (!self.controller.fit.pilot)
			return;
		
		
		eufe::Ship* ship = self.controller.fit.pilot->getShip();
		
		eufe::Module::Slot slots[] = {eufe::Module::SLOT_MODE, eufe::Module::SLOT_HI, eufe::Module::SLOT_MED, eufe::Module::SLOT_LOW, eufe::Module::SLOT_RIG, eufe::Module::SLOT_SUBSYSTEM};
		int n = sizeof(slots) / sizeof(eufe::Module::Slot);
		
		for (int i = 0; i < n; i++) {
			int numberOfSlots = ship->getNumberOfSlots(slots[i]);
			if (numberOfSlots > 0) {
				eufe::ModulesList modules;
				ship->getModules(slots[i], std::inserter(modules, modules.end()));
				
				NCFittingShipModulesViewControllerSection* section = [NCFittingShipModulesViewControllerSection new];
				section.slot = slots[i];
				section.numberOfSlots = numberOfSlots;
				NSMutableArray* rows = [NSMutableArray new];
				
				for (auto module: modules) {
					NCFittingShipModulesViewControllerRow* row = [NCFittingShipModulesViewControllerRow new];
					row.typeID = module->getTypeID();
					eufe::Charge* charge = module->getCharge();
					
					if (charge) {
						row.chargeID = charge->getTypeID();
						row.chargeVolume = charge->getAttribute(eufe::VOLUME_ATTRIBUTE_ID)->getValue();
						row.capacity = module->getAttribute(eufe::CAPACITY_ATTRIBUTE_ID)->getValue();
					}
					
					row.optimal = module->getMaxRange();
					row.falloff = module->getFalloff();
					row.trackingSpeed = module->getTrackingSpeed();
					row.lifeTime = module->getLifeTime();
					
					if (row.trackingSpeed > 0) {
						float v0 = ship->getMaxVelocityInOrbit(row.optimal);
						float v1 = ship->getMaxVelocityInOrbit(row.optimal + row.falloff);
						row.orbitRadius = ship->getOrbitRadiusWithAngularVelocity(row.trackingSpeed);
						row.trackingColor = row.trackingSpeed * row.optimal > v0 ? [UIColor greenColor] : (row.trackingSpeed * (row.optimal + row.falloff) > v1 ? [UIColor yellowColor] : [UIColor redColor]);
					}
					
					
					eufe::Module::Slot slot = module->getSlot();
					if (slot == eufe::Module::SLOT_HI || slot == eufe::Module::SLOT_MED || slot == eufe::Module::SLOT_LOW) {
						switch (module->getState()) {
							case eufe::Module::STATE_ACTIVE:
								row.stateImage = [UIImage imageNamed:@"active.png"];
								break;
							case eufe::Module::STATE_ONLINE:
								row.stateImage = [UIImage imageNamed:@"online.png"];
								break;
							case eufe::Module::STATE_OVERLOADED:
								row.stateImage = [UIImage imageNamed:@"overheated.png"];
								break;
							default:
								row.stateImage = [UIImage imageNamed:@"offline.png"];
								break;
						}
					}
					else
						row.stateImage = nil;
					
					row.hasTarget = module->getTarget() != NULL;
					[rows addObject:row];
				}
				
				
				[sections addObject:section];
				
				usedTurretHardpoints = ship->getUsedHardpoints(eufe::Module::HARDPOINT_TURRET);
				totalTurretHardpoints = ship->getNumberOfHardpoints(eufe::Module::HARDPOINT_TURRET);
				usedMissileHardpoints = ship->getUsedHardpoints(eufe::Module::HARDPOINT_LAUNCHER);
				totalMissileHardpoints = ship->getNumberOfHardpoints(eufe::Module::HARDPOINT_LAUNCHER);
			}
		}
	}];
	
	
	self.sections = sections;
	
	self.usedTurretHardpoints = usedTurretHardpoints;
	self.totalTurretHardpoints = totalTurretHardpoints;
	self.usedMissileHardpoints = usedMissileHardpoints;
	self.totalMissileHardpoints = totalMissileHardpoints;
	
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections.count;
	//return self.view.window ? self.sections.count : 0;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex {
	NCFittingShipModulesViewControllerSection* section = self.sections[sectionIndex];
	if (!section)
		return 0;
	else
		return std::max(section.numberOfSlots, static_cast<int>(section.modules.size()));
}

#pragma mark - Table view delegate

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)sectionIndex {
	NCFittingShipModulesViewControllerSection* section = self.sections[sectionIndex];
	
	if (section.slot == eufe::Module::SLOT_HI) {
		NCFittingSectionHiSlotHeaderView* header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"NCFittingSectionHiSlotHeaderView"];
		header.turretsLabel.text = [NSString stringWithFormat:@"%d/%d", self.usedTurretHardpoints, self.totalTurretHardpoints];
		header.launchersLabel.text = [NSString stringWithFormat:@"%d/%d", self.usedMissileHardpoints, self.totalMissileHardpoints];
		return header;
	}
	else {
		NCFittingSectionGenericHeaderView* header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"NCFittingSectionGenericHeaderView"];
		switch (section.slot) {
			case eufe::Module::SLOT_MED:
				header.imageView.image = [UIImage imageNamed:@"slotMed.png"];
				header.titleLabel.text = NSLocalizedString(@"Med slots", nil);
				break;
			case eufe::Module::SLOT_LOW:
				header.imageView.image = [UIImage imageNamed:@"slotLow.png"];
				header.titleLabel.text = NSLocalizedString(@"Low slots", nil);
				break;
			case eufe::Module::SLOT_RIG:
				header.imageView.image = [UIImage imageNamed:@"slotRig.png"];
				header.titleLabel.text = NSLocalizedString(@"Rig slots", nil);
				break;
			case eufe::Module::SLOT_SUBSYSTEM:
				header.imageView.image = [UIImage imageNamed:@"slotSubsystem.png"];
				header.titleLabel.text = NSLocalizedString(@"Subsystem slots", nil);
				break;
			case eufe::Module::SLOT_MODE:
			default:
				header.imageView.image = nil;
				header.titleLabel.text = NSLocalizedString(@"Tactical Mode", nil);
		}
		return header;
	}
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 44;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NCFittingShipModulesViewControllerSection* section = self.sections[indexPath.section];
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	if (indexPath.row >= section.modules.size() || section.slot == eufe::Module::SLOT_MODE) {
		eufe::Ship* ship = self.controller.fit.pilot->getShip();
		NCDBInvType* type = [self.controller typeWithItem:ship];
		NSString* title;
		NCDBEufeItemCategory* category;
		switch (section.slot) {
			case eufe::Module::SLOT_HI:
				title = NSLocalizedString(@"Hi slot", nil);
				category = [type.managedObjectContext categoryWithSlot:NCDBEufeItemSlotHi size:0 race:nil];
				break;
			case eufe::Module::SLOT_MED:
				title = NSLocalizedString(@"Med slot", nil);
				category = [type.managedObjectContext categoryWithSlot:NCDBEufeItemSlotMed size:0 race:nil];
				break;
			case eufe::Module::SLOT_LOW:
				title = NSLocalizedString(@"Low slot", nil);
				category = [type.managedObjectContext categoryWithSlot:NCDBEufeItemSlotLow size:0 race:nil];
				break;
			case eufe::Module::SLOT_RIG:
				title = NSLocalizedString(@"Rigs", nil);
				category = [type.managedObjectContext categoryWithSlot:NCDBEufeItemSlotRig size:ship->getAttribute(1547)->getValue() race:nil];
				break;
			case eufe::Module::SLOT_SUBSYSTEM: {
				int32_t raceID = static_cast<int32_t>(ship->getAttribute(eufe::RACE_ID_ATTRIBUTE_ID)->getValue());
				switch(raceID) {
					case 1: //Caldari
						title = NSLocalizedString(@"Caldari Subsystems", nil);
						break;
					case 2: //Minmatar
						title = NSLocalizedString(@"Minmatar Subsystems", nil);
						break;
					case 4: //Amarr
						title = NSLocalizedString(@"Amarr Subsystems", nil);
						break;
					case 8: //Gallente
						title = NSLocalizedString(@"Gallente Subsystems", nil);
						break;
				}
				category = [type.managedObjectContext categoryWithSlot:NCDBEufeItemSlotSubsystem size:0 race:type.race];
				break;
			}
			case eufe::Module::SLOT_MODE:
				title = NSLocalizedString(@"Tactical Mode", nil);
				category = [type.managedObjectContext categoryWithSlot:NCDBEufeItemSlotMode size:ship->getTypeID() race:nil];
				break;
			default:
				return;
		}
		self.controller.typePickerViewController.title = title;
		[self.controller.typePickerViewController presentWithCategory:category
													 inViewController:self.controller
															 fromRect:cell.bounds
															   inView:cell
															 animated:YES
													completionHandler:^(NCDBInvType *type) {
														if (section.slot == eufe::Module::SLOT_MODE) {
															eufe::ModulesList modes;
															ship->getModules(eufe::Module::SLOT_MODE, std::inserter(modes, modes.end()));
															for (auto i:modes)
																ship->removeModule(i);
														}
														ship->addModule(type.typeID);
														[self.controller reload];
														if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
															[self.controller dismissAnimated];
													}];
	}
	else {
		[self performActionForRowAtIndexPath:indexPath];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - NCTableViewController

- (NSString*) tableView:(UITableView *)tableView cellIdentifierForRowAtIndexPath:(NSIndexPath *)indexPath {
	NCFittingShipModulesViewControllerSection* section = self.sections[indexPath.section];
	if (indexPath.row >= section.modules.size())
		return @"Cell";
	else
		return @"NCFittingShipModuleCell";
}

- (void) tableView:(UITableView *)tableView configureCell:(UITableViewCell*) tableViewCell forRowAtIndexPath:(NSIndexPath*) indexPath {
	NCFittingShipModulesViewControllerSection* section = self.sections[indexPath.section];
	if (indexPath.row >= section.modules.size()) {
		NCDefaultTableViewCell* cell = (NCDefaultTableViewCell*) tableViewCell;
		cell.subtitleLabel.text = nil;
		cell.accessoryView = nil;
		switch (section.slot) {
			case eufe::Module::SLOT_HI:
				cell.iconView.image = [UIImage imageNamed:@"slotHigh.png"];
				cell.titleLabel.text = NSLocalizedString(@"High slot", nil);
				break;
			case eufe::Module::SLOT_MED:
				cell.iconView.image = [UIImage imageNamed:@"slotMed.png"];
				cell.titleLabel.text = NSLocalizedString(@"Med slot", nil);
				break;
			case eufe::Module::SLOT_LOW:
				cell.iconView.image = [UIImage imageNamed:@"slotLow.png"];
				cell.titleLabel.text = NSLocalizedString(@"Low slot", nil);
				break;
			case eufe::Module::SLOT_RIG:
				cell.iconView.image = [UIImage imageNamed:@"slotRig.png"];
				cell.titleLabel.text = NSLocalizedString(@"Rig slot", nil);
				break;
			case eufe::Module::SLOT_SUBSYSTEM:
				cell.iconView.image = [UIImage imageNamed:@"slotSubsystem.png"];
				cell.titleLabel.text = NSLocalizedString(@"Subsystem slot", nil);
				break;
			case eufe::Module::SLOT_MODE:
				cell.iconView.image = [UIImage imageNamed:@"ships.png"];
				cell.titleLabel.text = NSLocalizedString(@"Tactical mode", nil);
				break;
			default:
				cell.iconView.image = nil;
				cell.titleLabel.text = nil;
		}
	}
	else {
		//		@synchronized(self.controller) {
		NCFittingShipModuleCell* cell = (NCFittingShipModuleCell*) tableViewCell;
		eufe::Module* module = section.modules[indexPath.row];
		NCDBInvType* type = [self.controller typeWithItem:module];
		cell.typeNameLabel.text = type.typeName;
		cell.typeImageView.image = type.icon ? type.icon.image.image : [[[type.managedObjectContext defaultTypeIcon] image] image];
		
		eufe::Charge* charge = module->getCharge();
		eufe::Ship* ship = self.controller.fit.pilot->getShip();

		if (charge) {
			type = [self.controller typeWithItem:charge];
			float volume = charge->getAttribute(eufe::VOLUME_ATTRIBUTE_ID)->getValue();
			float capacity = module->getAttribute(eufe::CAPACITY_ATTRIBUTE_ID)->getValue();
			if (volume > 0 && capacity > 0)
				cell.chargeLabel.text = [NSString stringWithFormat:@"%@ x %d", type.typeName, (int)(capacity / volume)];
			else
				cell.chargeLabel.text = type.typeName;
		}
		else
			cell.chargeLabel.text = nil;
		
		float optimal = module->getMaxRange();
		float falloff = module->getFalloff();
		float trackingSpeed = module->getTrackingSpeed();
		float lifeTime = module->getLifeTime();
		
		if (optimal > 0) {
			NSMutableString* s = [NSMutableString stringWithFormat:NSLocalizedString(@"%@m", nil), [NSNumberFormatter neocomLocalizedStringFromNumber:@(optimal)]];
			if (falloff > 0)
				[s appendFormat:NSLocalizedString(@" + %@m", nil), [NSNumberFormatter neocomLocalizedStringFromNumber:@(falloff)]];
			cell.optimalLabel.text = s;
		}
		else
			cell.optimalLabel.text = nil;
		
		if (trackingSpeed > 0) {
			float v0 = ship->getMaxVelocityInOrbit(optimal);
			float v1 = ship->getMaxVelocityInOrbit(optimal + falloff);
			
			double r = ship->getOrbitRadiusWithAngularVelocity(trackingSpeed);
			
			UIColor* color = trackingSpeed * optimal > v0 ? [UIColor greenColor] : (trackingSpeed * (optimal + falloff) > v1 ? [UIColor yellowColor] : [UIColor redColor]);
			
			NSMutableAttributedString* s = [NSMutableAttributedString new];
			
			[s appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ rad/sec (", nil), [NSNumberFormatter neocomLocalizedStringFromNumber:@(trackingSpeed)]]
																	  attributes:nil]];
			NSTextAttachment* icon;
			icon = [NSTextAttachment new];
			icon.image = [UIImage imageNamed:@"targetingRange.png"];
			icon.bounds = CGRectMake(0, -7 -cell.trackingLabel.font.descender, 15, 15);
			[s appendAttributedString:[NSAttributedString attributedStringWithAttachment:icon]];
			[s appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%@+ m)", nil),
																				  [NSNumberFormatter neocomLocalizedStringFromNumber:@(r)]]
																	  attributes:nil]];
			cell.trackingLabel.attributedText = s;
			cell.trackingLabel.textColor = color;
		}
		else
			cell.trackingLabel.text = nil;

		
		if (lifeTime > 0)
			cell.lifetimeLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Lifetime: %@", nil), [NSString stringWithTimeLeft:lifeTime]];
		else
			cell.lifetimeLabel.text = nil;
		
		eufe::Module::Slot slot = module->getSlot();
		if (slot == eufe::Module::SLOT_HI || slot == eufe::Module::SLOT_MED || slot == eufe::Module::SLOT_LOW) {
			switch (module->getState()) {
				case eufe::Module::STATE_ACTIVE:
					cell.stateImageView.image = [UIImage imageNamed:@"active.png"];
					break;
				case eufe::Module::STATE_ONLINE:
					cell.stateImageView.image = [UIImage imageNamed:@"online.png"];
					break;
				case eufe::Module::STATE_OVERLOADED:
					cell.stateImageView.image = [UIImage imageNamed:@"overheated.png"];
					break;
				default:
					cell.stateImageView.image = [UIImage imageNamed:@"offline.png"];
					break;
			}
		}
		else
			cell.stateImageView.image = nil;
		
		cell.targetImageView.image = module->getTarget() != NULL ? [[[type.managedObjectContext eveIconWithIconFile:@"04_12"] image] image] : nil;
		//		}
		
	}
}

#pragma mark - Private

- (void) performActionForRowAtIndexPath:(NSIndexPath*) indexPath {
	NCFittingShipModulesViewControllerSection* section = self.sections[indexPath.section];
	UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
	
	eufe::Ship* ship = self.controller.fit.pilot->getShip();
	eufe::Module* module = section.modules[indexPath.row];
	NCDBInvType* type = [self.controller typeWithItem:module];
	
	//NSMutableArray* allSimilarModules = [NSMutableArray new];
	eufe::ModulesList allSimilarModules;
	
	bool multiple = false;
	for (auto module: section.modules) {
		NCDBInvType* moduleType = [self.controller typeWithItem:module];
		if (type.marketGroup.marketGroupID == moduleType.marketGroup.marketGroupID)
			allSimilarModules.push_back(module);
	}
	multiple = allSimilarModules.size() > 1;
	
	
	eufe::Module::State state = module->getState();
	
	void (^remove)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules) {
			section.modules.erase(std::find(section.modules.begin(), section.modules.end(), module));
			ship->removeModule(module);
		}
		[self.controller reload];
	};
	
	void (^putOffline)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->setState(eufe::Module::STATE_OFFLINE);
		[self.controller reload];
	};
	void (^putOnline)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules) {
			if (module->canHaveState(eufe::Module::STATE_ACTIVE))
				module->setState(eufe::Module::STATE_ACTIVE);
			else
				module->setState(eufe::Module::STATE_ONLINE);
		}
		[self.controller reload];
	};
	void (^activate)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->setState(eufe::Module::STATE_ACTIVE);
		[self.controller reload];
	};
	void (^deactivate)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->setState(eufe::Module::STATE_ONLINE);
		[self.controller reload];
	};
	void (^enableOverheating)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->setState(eufe::Module::STATE_OVERLOADED);
		[self.controller reload];
	};
	void (^disableOverheating)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->setState(eufe::Module::STATE_ACTIVE);
		[self.controller reload];
	};
	
	NSMutableArray* statesButtons = [NSMutableArray new];
	NSMutableArray* statesActions = [NSMutableArray new];
	
	if (state >= eufe::Module::STATE_ACTIVE) {
		[statesButtons addObject:ActionButtonOffline];
		[statesActions addObject:putOffline];
		
		[statesButtons addObject:ActionButtonDeactivate];
		[statesActions addObject:deactivate];
		
		if (module->canHaveState(eufe::Module::STATE_OVERLOADED)) {
			if (state == eufe::Module::STATE_OVERLOADED) {
				[statesButtons addObject:ActionButtonOverheatOff];
				[statesActions addObject:disableOverheating];
			}
			else {
				[statesButtons addObject:ActionButtonOverheatOn];
				[statesActions addObject:enableOverheating];
			}
		}
	}
	else if (state == eufe::Module::STATE_ONLINE) {
		[statesButtons addObject:ActionButtonOffline];
		[statesActions addObject:putOffline];
		if (module->canHaveState(eufe::Module::STATE_ACTIVE)) {
			[statesButtons addObject:ActionButtonActivate];
			[statesActions addObject:activate];
		}
	}
	else {
		if (module->canHaveState(eufe::Module::STATE_ONLINE)) {
			[statesButtons addObject:ActionButtonOnline];
			[statesActions addObject:putOnline];
		}
	}
	
	void (^setAmmo)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		int chargeSize = module->getChargeSize();
		
		NSMutableArray *groups = [NSMutableArray new];
		for (auto i: module->getChargeGroups())
			[groups addObject:[NSString stringWithFormat:@"%d", i]];
		
		self.controller.typePickerViewController.title = NSLocalizedString(@"Ammo", nil);
		NSArray* conditions;
		if (chargeSize)
			conditions = @[@"invTypes.typeID=dgmTypeAttributes.typeID",
						   @"dgmTypeAttributes.attributeID=128",
						   [NSString stringWithFormat:@"dgmTypeAttributes.value=%d", chargeSize],
						   [NSString stringWithFormat:@"groupID IN (%@)", [groups componentsJoinedByString:@","]]];
		else
			conditions = @[[NSString stringWithFormat:@"groupID IN (%@)", [groups componentsJoinedByString:@","]],
						   [NSString stringWithFormat:@"invTypes.volume <= %f", module->getAttribute(eufe::CAPACITY_ATTRIBUTE_ID)->getValue()]];
		
		[self.controller.typePickerViewController presentWithCategory:type.eufeItem.charge
													 inViewController:self.controller
															 fromRect:cell.bounds
															   inView:cell
															 animated:YES
													completionHandler:^(NCDBInvType *type) {
														for (auto module: modules)
															module->setCharge(type.typeID);
														[self.controller reload];
														[self.controller dismissAnimated];
													}];
	};
	void (^unloadAmmo)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->clearCharge();
		[self.controller reload];
	};
	
	void (^changeState)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		[[UIActionSheet actionSheetWithStyle:UIActionSheetStyleBlackTranslucent
									   title:nil
						   cancelButtonTitle:NSLocalizedString(@"Cancel", )
					  destructiveButtonTitle:nil
						   otherButtonTitles:statesButtons
							 completionBlock:^(UIActionSheet *actionSheet, NSInteger selectedButtonIndex) {
								 if (selectedButtonIndex != actionSheet.cancelButtonIndex) {
									 void (^block)(eufe::ModulesList) = statesActions[selectedButtonIndex];
									 eufe::ModulesList modules;
									 modules.push_back(module);
									 block(modules);
								 }
							 } cancelBlock:nil] showFromRect:cell.bounds inView:cell animated:YES];
	};
	
	void (^moduleInfo)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		[self.controller performSegueWithIdentifier:@"NCDatabaseTypeInfoViewController"
											 sender:@{@"sender": cell, @"object": [NSValue valueWithPointer:module]}];
	};
	void (^ammoInfo)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		[self.controller performSegueWithIdentifier:@"NCDatabaseTypeInfoViewController"
											 sender:@{@"sender": cell, @"object": [NSValue valueWithPointer:module->getCharge()]}];
	};
	
	void (^setTarget)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		NSMutableArray* array = [NSMutableArray new];
		for (auto module: modules)
			[array addObject:[NSValue valueWithPointer:module]];
		[self.controller performSegueWithIdentifier:@"NCFittingTargetsViewController"
											 sender:@{@"sender": cell, @"object": array}];
	};
	void (^clearTarget)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		for (auto module: modules)
			module->clearTarget();
		[self.controller reload];
	};
	
	void (^variations)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		NSMutableArray* array = [NSMutableArray new];
		for (auto module: modules)
			[array addObject:[NSValue valueWithPointer:module]];
		
		[self.controller performSegueWithIdentifier:@"NCFittingTypeVariationsViewController"
											 sender:@{@"sender": cell, @"object": array}];
	};
	
	void (^similarModules)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		NSMutableArray* buttons = [NSMutableArray new];
		NSMutableArray* actions = [NSMutableArray new];
		
		[actions addObject:remove];
		[buttons addObjectsFromArray:statesButtons];
		[actions addObjectsFromArray:statesActions];
		
		if (module->getChargeGroups().size() > 0) {
			[buttons addObject:ActionButtonAmmo];
			[actions addObject:setAmmo];
			
			if (module->getCharge() != nil) {
				[buttons addObject:ActionButtonUnloadAmmo];
				[actions addObject:unloadAmmo];
			}
		}
		[buttons addObject:ActionButtonVariations];
		[actions addObject:variations];
		
		if (module->requireTarget() && self.controller.fits.count > 1) {
			[buttons addObject:ActionButtonSetTarget];
			[actions addObject:setTarget];
			if (module->getTarget() != NULL) {
				[buttons addObject:ActionButtonClearTarget];
				[actions addObject:clearTarget];
			}
		}
		
		[[UIActionSheet actionSheetWithStyle:UIActionSheetStyleBlackTranslucent
									   title:nil
						   cancelButtonTitle:NSLocalizedString(@"Cancel", )
					  destructiveButtonTitle:ActionButtonDelete
						   otherButtonTitles:buttons
							 completionBlock:^(UIActionSheet *actionSheet, NSInteger selectedButtonIndex) {
								 if (selectedButtonIndex != actionSheet.cancelButtonIndex) {
									 void (^block)(eufe::ModulesList) = actions[selectedButtonIndex];
									 block(allSimilarModules);
								 }
							 } cancelBlock:nil] showFromRect:cell.bounds inView:cell animated:YES];
	};
	
	void (^affectingSkills)(eufe::ModulesList) = ^(eufe::ModulesList modules){
		[self.controller performSegueWithIdentifier:@"NCFittingShipAffectingSkillsViewController"
											 sender:@{@"sender": cell, @"object": [NSValue valueWithPointer:module]}];
	};
	
	NSMutableArray* buttons = [NSMutableArray new];
	NSMutableArray* actions = [NSMutableArray new];
	
	[actions addObject:remove];
	
	[buttons addObject:ActionButtonShowModuleInfo];
	[actions addObject:moduleInfo];
	if (module->getCharge() != NULL) {
		[buttons addObject:ActionButtonShowAmmoInfo];
		[actions addObject:ammoInfo];
	}
	
	
	
	if (statesButtons.count > 0) {
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
			[buttons addObjectsFromArray:statesButtons];
			[actions addObjectsFromArray:statesActions];
		}
		else {
			[buttons addObject:ActionButtonChangeState];
			[actions addObject:changeState];
		}
	}
	
	if (module->getChargeGroups().size() > 0) {
		[buttons addObject:ActionButtonAmmo];
		[actions addObject:setAmmo];
		
		if (module->getCharge() != nil) {
			[buttons addObject:ActionButtonUnloadAmmo];
			[actions addObject:unloadAmmo];
		}
	}
	if (module->requireTarget() && self.controller.fits.count > 1) {
		[buttons addObject:ActionButtonSetTarget];
		[actions addObject:setTarget];
		if (module->getTarget() != NULL) {
			[buttons addObject:ActionButtonClearTarget];
			[actions addObject:clearTarget];
		}
	}
	[buttons addObject:ActionButtonVariations];
	[actions addObject:variations];
	
	[buttons addObject:ActionButtonAffectingSkills];
	[actions addObject:affectingSkills];
	
	if (multiple) {
		[buttons addObject:ActionButtonAllSimilarModules];
		[actions addObject:similarModules];
	}
	
	[[UIActionSheet actionSheetWithStyle:UIActionSheetStyleBlackTranslucent
								   title:nil
					   cancelButtonTitle:NSLocalizedString(@"Cancel", )
				  destructiveButtonTitle:ActionButtonDelete
					   otherButtonTitles:buttons
						 completionBlock:^(UIActionSheet *actionSheet, NSInteger selectedButtonIndex) {
							 if (selectedButtonIndex != actionSheet.cancelButtonIndex) {
								 void (^block)(eufe::ModulesList) = actions[selectedButtonIndex];
								 eufe::ModulesList modules;
								 modules.push_back(module);
								 block(modules);
							 }
						 } cancelBlock:nil] showFromRect:cell.bounds inView:cell animated:YES];
}

@end
