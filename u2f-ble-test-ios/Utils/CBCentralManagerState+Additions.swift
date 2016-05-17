//
//  CBCentralManagerState+Additions.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import CoreBluetooth

extension CBCentralManagerState: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .PoweredOff: return "PoweredOff"
        case .PoweredOn: return "PoweredOn"
        case .Resetting: return "Resetting"
        case .Unauthorized: return "Unauthorized"
        case .Unsupported: return "Unsupported"
        case .Unknown: return "Unknown"
        }
    }
    
}