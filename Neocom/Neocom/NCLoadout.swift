//
//  NCLoadout.swift
//  Neocom
//
//  Created by Artem Shimanski on 11.01.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit

class NCFittingLoadoutItem: NSObject, NSCoding {
	let typeID: Int
	let count: Int
	
	required init?(coder aDecoder: NSCoder) {
		typeID = aDecoder.decodeInteger(forKey: "typeID")
		count = aDecoder.decodeObject(forKey: "count") as? Int ?? 1
		super.init()
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(typeID, forKey: "typeID")
		if count != 1 {
			aCoder.encode(count, forKey: "count")
		}
	}
	
	public static func ==(lhs: NCFittingLoadoutItem, rhs: NCFittingLoadoutItem) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
	
	override var hashValue: Int {
		return [typeID, count].hashValue
	}
}

class NCFittingLoadoutModule: NCFittingLoadoutItem {
	let state: NCFittingModuleState
	let charge: NCFittingLoadoutItem?
	
	required init?(coder aDecoder: NSCoder) {
		state = NCFittingModuleState(rawValue: aDecoder.decodeInteger(forKey: "state")) ?? .unknown
		charge = aDecoder.decodeObject(forKey: "charge") as? NCFittingLoadoutItem
		super.init(coder: aDecoder)
	}
	
	override func encode(with aCoder: NSCoder) {
		super.encode(with: aCoder)
		aCoder.encode(state.rawValue, forKey: "state")
		aCoder.encode(charge, forKey: "charge")
	}

	override var hashValue: Int {
		return [typeID, count, state.rawValue, charge?.typeID ?? 0].hashValue
	}
}

class NCFittingLoadoutDrone: NCFittingLoadoutItem {
	let isActive: Bool
	
	required init?(coder aDecoder: NSCoder) {
		isActive = aDecoder.decodeObject(forKey: "isActive") as? Bool ?? true
		super.init(coder: aDecoder)
	}
	
	override func encode(with aCoder: NSCoder) {
		super.encode(with: aCoder)
		if !isActive {
			aCoder.encode(isActive, forKey: "isActive")
		}
	}

	override var hashValue: Int {
		return [typeID, count, isActive ? 1 : 0].hashValue
	}
}


class NCFittingLoadout: NSObject, NSCoding {
	var modules: [NCFittingModuleSlot: [NCFittingLoadoutModule]]?
	var drones: [NCFittingLoadoutDrone]?
	var cargo: [NCFittingLoadoutItem]?
	var implants: [NCFittingLoadoutItem]?
	var boosters: [NCFittingLoadoutItem]?
	
	required init?(coder aDecoder: NSCoder) {
		modules = [NCFittingModuleSlot: [NCFittingLoadoutModule]]()
		for (key, value) in aDecoder.decodeObject(forKey: "modules") as? [Int: [NCFittingLoadoutModule]] ?? [:] {
			guard let key = NCFittingModuleSlot(rawValue: key) else {continue}
			modules?[key] = value
		}
		
		drones = aDecoder.decodeObject(forKey: "drones") as? [NCFittingLoadoutDrone]
		cargo = aDecoder.decodeObject(forKey: "cargo") as? [NCFittingLoadoutItem]
		implants = aDecoder.decodeObject(forKey: "implants") as? [NCFittingLoadoutItem]
		boosters = aDecoder.decodeObject(forKey: "boosters") as? [NCFittingLoadoutItem]
		super.init()
	}
	
	func encode(with aCoder: NSCoder) {
		var dic = [Int: [NCFittingLoadoutModule]]()
		for (key, value) in modules ?? [:] {
			dic[key.rawValue] = value
		}
		
		aCoder.encode(dic, forKey:"modules")

		if drones?.count ?? 0 > 0 {
			aCoder.encode(drones, forKey: "drones")
		}
		if cargo?.count ?? 0 > 0 {
			aCoder.encode(cargo, forKey: "cargo")
		}
		if implants?.count ?? 0 > 0 {
			aCoder.encode(implants, forKey: "implants")
		}
		if boosters?.count ?? 0 > 0 {
			aCoder.encode(boosters, forKey: "boosters")
		}
	}
}