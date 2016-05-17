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
    var onReceivedAPDU: ((BluetoothManager, NSData) -> Void)?
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
    
    func exchangeAPDU(data: NSData) {
        guard state == .Connected else { return }
        
        // send data
        onDebugMessage?(self, "Exchanging APDU = \(data)")
        deviceManager?.exchangeAPDU(data)
    }
    
    private func handleDeviceManagerStateChanged(deviceManager: DeviceManager, state: DeviceManagerState) {
        if state == .Bound {
            onDebugMessage?(self, "Successfully connected device \(deviceManager.peripheral.identifier.UUIDString)")
            self.state = .Connected
        }
        else if state == .Binding {
            onDebugMessage?(self, "Binding to device \(deviceManager.peripheral.identifier.UUIDString)...")
        }
        else if state == .NotBound {
            onDebugMessage?(self, "Something when wrong with device \(deviceManager.peripheral.identifier.UUIDString)")
            stopSession()
        }
    }
    
    private func handleDeviceManagerDebugMessage(deviceManager: DeviceManager, message: String) {
        onDebugMessage?(self, message)
    }
    
    private func handleDeviceManagerReceivedAPDU(deviceManager: DeviceManager, data: NSData) {
        onReceivedAPDU?(self, data)
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
            onDebugMessage?(self, "Bluetooth stack is ready, scanning devices...")
            let serviceUUID = CBUUID(string: DeviceManager.deviceServiceUUID)
            central.scanForPeripheralsWithServices([serviceUUID], options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        guard state == .Scanning else { return }
        guard let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber where connectable.boolValue == true else { return }
        
        // a device has been found
        onDebugMessage?(self, "Found connectable device \"\(peripheral.name)\", connecting \(peripheral.identifier.UUIDString)...")
        deviceManager = DeviceManager(peripheral: peripheral)
        deviceManager?.onStateChanged = handleDeviceManagerStateChanged
        deviceManager?.onDebugMessage = handleDeviceManagerDebugMessage
        deviceManager?.onAPDUReceived = handleDeviceManagerReceivedAPDU
        central.stopScan()
        central.connectPeripheral(peripheral, options: nil)
        state = .Connecting
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        guard state == .Connecting, let deviceManager = deviceManager else { return }
        
        // we're connected, bind to characteristics
        deviceManager.bindForReadWrite()
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard state == .Connecting, let _ = deviceManager else { return }
        
        // failed to connect
        onDebugMessage?(self, "Failed to connect device \(peripheral.identifier.UUIDString), error: \(error?.description)")
        resetState()
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard state == .Connecting || state == .Connected || state == .Disconnecting, let _ = deviceManager else { return }
        
        // destroy central
        onDebugMessage?(self, "Disconnected device \(peripheral.identifier.UUIDString), error: \(error?.description)")
        resetState()
    }

}