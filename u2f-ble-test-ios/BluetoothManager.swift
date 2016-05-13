//
//  BluetoothManager.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import CoreBluetooth

private let deviceServiceUUID = "0000FFFD-0000-1000-8000-00805F9B34FB"
private let writeCharacteristicUUID = "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"
private let notifyCharacteristicUUID = "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"

enum BluetoothManagerState: String {
    case Scanning
    case Connecting
    case Connected
    case Disconnecting
    case Disconnected
}

final class BluetoothManager: NSObject {
    
    var onStateChanged: ((BluetoothManager, BluetoothManagerState) -> Void)?
    private var centralManager: CBCentralManager?
    private var bluetoothDevice: CBPeripheral?
    private(set) var state = BluetoothManagerState.Disconnected {
        didSet {
            onStateChanged?(self, self.state)
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
        else if state == .Connecting || state == .Connected, let device = bluetoothDevice {
            centralManager.cancelPeripheralConnection(device)
            state = .Disconnecting
        }
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn && state == .Scanning {
            // bluetooth stack is ready, start scanning
            let serviceUUID = CBUUID(string: deviceServiceUUID)
            central.scanForPeripheralsWithServices([serviceUUID], options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        guard state == .Scanning else { return }
        guard let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber where connectable.boolValue == true else { return }
        
        // a device has been found
        bluetoothDevice = peripheral
        central.stopScan()
        central.connectPeripheral(peripheral, options: nil)
        state = .Connecting
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        guard state == .Connecting else { return }
        
        // we're connected
        state = .Connected
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard state == .Connecting else { return }
        
        // fallback to disconnection
        centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        guard state == .Connecting || state == .Connected || state == .Disconnecting else { return }
        
        // destroy central
        bluetoothDevice = nil
        centralManager = nil
        state = .Disconnected
    }

}