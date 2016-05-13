//
//  BluetoothManager.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import CoreBluetooth

enum BluetoothManagerState: String {
    case Scanning
    case Connecting
    case Connected
    case Disconnecting
    case Disconnected
}

final class BluetoothManager: NSObject {
    
    var onStateChanged: ((BluetoothManager, BluetoothManagerState) -> Void)?
    var onDebugMessage: ((BluetoothManager, String) -> Void)?
    var deviceName: String? { return deviceManager?.deviceName }
    
    private var centralManager: CBCentralManager?
    private var deviceManager: DeviceManager?
    private(set) var state = BluetoothManagerState.Disconnected {
        didSet {
            onStateChanged?(self, self.state)
            onDebugMessage?(self, "New state: \(self.state.rawValue)")
        }
    }
    
    func scanForDevice() {
        guard centralManager == nil else { return }
        
        // create central
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: NSNumber(bool: true)])
        state = .Scanning
    }
    
    func stopSession() {
        guard let centralManager = centralManager else { return }
        
        // handle disconnection
        if state == .Scanning {
            centralManager.stopScan()
            self.centralManager = nil
            state = .Disconnected
        }
        else if state == .Connecting || state == .Connected, let device = deviceManager?.peripheral {
            centralManager.cancelPeripheralConnection(device)
            state = .Disconnecting
        }
    }
    
    private func resetState() {
        deviceManager = nil
        centralManager = nil
        state = .Disconnected
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn && state == .Scanning {
            // bluetooth stack is ready, start scanning
            onDebugMessage?(self, "Bluetooth stack is ready, scanning devices")
            let serviceUUID = CBUUID(string: DeviceManager.serviceUUID)
            central.scanForPeripheralsWithServices([serviceUUID], options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        guard state == .Scanning else { return }
        guard let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber where connectable.boolValue == true else { return }
        
        // a device has been found
        onDebugMessage?(self, "Found connectable device \"\(peripheral.name)\", connecting \(peripheral.identifier.UUIDString)")
        deviceManager = DeviceManager(peripheral: peripheral)
        central.stopScan()
        central.connectPeripheral(peripheral, options: nil)
        state = .Connecting
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        guard state == .Connecting else { return }
        
        // we're connected
        onDebugMessage?(self, "Successfully connected device \(peripheral.identifier.UUIDString)")
        state = .Connected
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard state == .Connecting else { return }
        
        // failed to connect
        onDebugMessage?(self, "Failed to connect device \(peripheral.identifier.UUIDString), error: \(error?.description)")
        resetState()
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard state == .Connecting || state == .Connected || state == .Disconnecting else { return }
        
        // destroy central
        onDebugMessage?(self, "Disconnected device \(peripheral.identifier.UUIDString), error: \(error?.description)")
        resetState()
    }

}