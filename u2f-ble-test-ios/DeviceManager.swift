//
//  DeviceManager.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import CoreBluetooth

enum DeviceManagerState: String {
    case NotBound
    case Binding
    case Bound
}

final class DeviceManager: NSObject {
    
    static let deviceServiceUUID = "0000FFFD-0000-1000-8000-00805F9B34FB"
    static let writeCharacteristicUUID = "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"
    static let notifyCharacteristicUUID = "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"
    
    let peripheral: CBPeripheral
    var deviceName: String? { return peripheral.name }
    var writeCharacteristic: CBCharacteristic?
    var notifyCharacteristic: CBCharacteristic?
    private(set) var state = DeviceManagerState.NotBound {
        didSet {
            onStateChanged?(self, self.state)
        }
    }
    var onStateChanged: ((DeviceManager, DeviceManagerState) -> Void)?
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.delegate = self
    }
    
    func bindForReadWrite() {
        // discover services
        state = .Binding
        let serviceUUID = CBUUID(string: self.dynamicType.deviceServiceUUID)
        peripheral.discoverServices([serviceUUID])
    }
    
    private func resetState() {
        writeCharacteristic = nil
        notifyCharacteristic = nil
        state = .NotBound
    }
    
}

extension DeviceManager: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        guard state == .Binding else { return }
        guard
            let services = peripheral.services where services.count > 0,
            let service = services.first
        else {
            resetState()
            return
        }
        
        // discover characteristics
        let writeCharacteristicUUID = CBUUID(string: self.dynamicType.writeCharacteristicUUID)
        let notifyCharacteristicUUID = CBUUID(string: self.dynamicType.notifyCharacteristicUUID)
        peripheral.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID], forService: service)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        guard state == .Binding else { return }
        guard
            let characteristics = service.characteristics where characteristics.count >= 2,
            let writeCharacteristic = characteristics.filter({ $0.UUID.UUIDString == self.dynamicType.writeCharacteristicUUID }).first,
            let notifyCharacteristic = characteristics.filter({ $0.UUID.UUIDString == self.dynamicType.notifyCharacteristicUUID }).first
        else {
            resetState()
            return
        }
    
        // ask for notifications
        self.writeCharacteristic = writeCharacteristic
        self.notifyCharacteristic = notifyCharacteristic
        peripheral.setNotifyValue(true, forCharacteristic: notifyCharacteristic)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard state == .Binding else { return }
        guard characteristic.isNotifying else {
            resetState()
            return
        }
        
        // successfully bound
        state = .Bound
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
    }
    
}