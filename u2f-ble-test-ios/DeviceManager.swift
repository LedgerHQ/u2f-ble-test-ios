//
//  DeviceManager.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import CoreBluetooth

final class DeviceManager: NSObject {
    
    static let serviceUUID = "0000FFFD-0000-1000-8000-00805F9B34FB"
    static let writeCharacteristicUUID = "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"
    static let notifyCharacteristicUUID = "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"

    var deviceName: String? { return peripheral.name }
    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.delegate = self
    }
    
    func bindForReadWrite() {
        
    }
    
}

extension DeviceManager: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
    }
    
}