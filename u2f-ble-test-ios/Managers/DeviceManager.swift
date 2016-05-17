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
    static let controlpointLengthCharacteristicUUID = "F1D0FFF3-DEAA-ECEE-B42F-C9BA7ED623BB"
    
    let peripheral: CBPeripheral
    var deviceName: String? { return peripheral.name }
    var onStateChanged: ((DeviceManager, DeviceManagerState) -> Void)?
    var onDebugMessage: ((DeviceManager, String) -> Void)?
    var onAPDUReceived: ((DeviceManager, NSData) -> Void)?
    
    private var chunksize = 0
    private var pendingChunks: [NSData] = []
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var controlpointLengthCharacteristic: CBCharacteristic?
    private(set) var state = DeviceManagerState.NotBound {
        didSet {
            onStateChanged?(self, self.state)
        }
    }
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.delegate = self
    }
    
    func bindForReadWrite() {
        guard state == .NotBound else {
            onDebugMessage?(self, "Trying to bind but alreay busy")
            return
        }
        
        // discover services
        onDebugMessage?(self, "Discovering services...")
        state = .Binding
        let serviceUUID = CBUUID(string: self.dynamicType.deviceServiceUUID)
        peripheral.discoverServices([serviceUUID])
    }
    
    func exchangeAPDU(data: NSData) {
        guard state == .Bound else {
            onDebugMessage?(self, "Trying to send APDU \(data) but not bound yet")
            return
        }
        
        // slice APDU
        onDebugMessage?(self, "Trying to split APDU into chunks...")
        if let chunks = TransportHelper.split(data, command: .Message, chuncksize: chunksize) where chunks.count > 0 {
            onDebugMessage?(self, "Successfully split APDU into \(chunks.count) part(s)")
            pendingChunks = chunks
            writeNextPendingChunk()
        }
        else {
            onDebugMessage?(self, "Unable to split APDU into chunks")
            resetState()
        }
    }
    
    private func writeNextPendingChunk() {
        guard pendingChunks.count > 0 else {
            onDebugMessage?(self, "Trying to write pending chunk but nothing left to write")
            return
        }
        
        let chunk = pendingChunks.removeFirst()
        onDebugMessage?(self, "Writing pending chunk = \(chunk)")
        peripheral.writeValue(chunk, forCharacteristic: writeCharacteristic!, type: .WithResponse)
    }
    
    private func handleReceivedChunk(chunk: NSData) {
        // get chunk type
        switch TransportHelper.getChunkType(chunk) {
        case .Continuation:
            //onDebugMessage?(self, "Received CONTINUATION chunk")
            break
        case .Message:
            //onDebugMessage?(self, "Received MESSAGE chunk")
            break
        case .Error:
            //onDebugMessage?(self, "Received ERROR chunk")
            return
        case .KeepAlive:
            //onDebugMessage?(self, "Received KEEPALIVE chunk")
            return
        default:
            //onDebugMessage?(self, "Received UNKNOWN chunk")
            break
        }
        
        // join APDU
        pendingChunks.append(chunk)
        if let APDU = TransportHelper.join(pendingChunks, command: .Message) {
            onDebugMessage?(self, "Successfully joined APDU = \(APDU)")
            pendingChunks.removeAll()
            onAPDUReceived?(self, APDU)
        }
    }
    
    private func resetState() {
        writeCharacteristic = nil
        notifyCharacteristic = nil
        controlpointLengthCharacteristic = nil
        chunksize = 0
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
            onDebugMessage?(self, "Unable to discover services")
            resetState()
            return
        }
        
        // discover characteristics
        onDebugMessage?(self, "Successfully discovered services")
        let writeCharacteristicUUID = CBUUID(string: self.dynamicType.writeCharacteristicUUID)
        let notifyCharacteristicUUID = CBUUID(string: self.dynamicType.notifyCharacteristicUUID)
        let controlpointLengthCharacteristicUUID = CBUUID(string: self.dynamicType.controlpointLengthCharacteristicUUID)
        onDebugMessage?(self, "Discovering characteristics...")
        peripheral.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID, controlpointLengthCharacteristicUUID], forService: service)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        guard state == .Binding else { return }
        guard
            let characteristics = service.characteristics where characteristics.count >= 3,
            let writeCharacteristic = characteristics.filter({ $0.UUID.UUIDString == self.dynamicType.writeCharacteristicUUID }).first,
            let notifyCharacteristic = characteristics.filter({ $0.UUID.UUIDString == self.dynamicType.notifyCharacteristicUUID }).first,
            let controlpointLengthCharacteristic = characteristics.filter({ $0.UUID.UUIDString == self.dynamicType.controlpointLengthCharacteristicUUID }).first
        else {
            onDebugMessage?(self, "Unable to discover characteristics")
            resetState()
            return
        }
    
        // retain characteristics
        onDebugMessage?(self, "Successfully discovered characteristics")
        self.writeCharacteristic = writeCharacteristic
        self.notifyCharacteristic = notifyCharacteristic
        self.controlpointLengthCharacteristic = controlpointLengthCharacteristic
        
        // ask for notifications
        onDebugMessage?(self, "Enabling notifications...")
        peripheral.setNotifyValue(true, forCharacteristic: notifyCharacteristic)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard state == .Binding else { return }
        guard characteristic == notifyCharacteristic && characteristic.isNotifying && error == nil else {
            onDebugMessage?(self, "Unable to enable notifications, error = \(error)")
            resetState()
            return
        }
        
        // ask for chunksize
        onDebugMessage?(self, "Successfully enabled notifications")
        onDebugMessage?(self, "Reading chunksize...")
        peripheral.readValueForCharacteristic(self.controlpointLengthCharacteristic!)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard state == .Bound || state == .Binding else { return }
        guard
            (characteristic == notifyCharacteristic || characteristic == controlpointLengthCharacteristic) && error == nil,
            let data = characteristic.value
        else {
            onDebugMessage?(self, "Unable to read data, error = \(error), data = \(characteristic.value)")
            resetState()
            return
        }
        
        // received data
        onDebugMessage?(self, "Received data of size \(data.length) = \(data)")
        
        if characteristic == controlpointLengthCharacteristic {
            // extract chunksize
            let reader = DataReader(data: data)
            guard let chunksize = reader.readNextBigEndianUInt16() else {
                onDebugMessage?(self, "Unable to read chunksize")
                resetState()
                return
            }
            
            // successfully bound
            onDebugMessage?(self, "Successfully read chuncksize = \(chunksize)")
            self.chunksize = Int(chunksize)
            state = .Bound
        }
        else if characteristic == notifyCharacteristic {
            // handle received data
            handleReceivedChunk(data)
        }
        else {
            // unknown characteristic
            onDebugMessage?(self, "Received data from unknown characteristic, ignoring")
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard state == .Bound else { return }
        guard characteristic == writeCharacteristic && error == nil else {
            onDebugMessage?(self, "Unable to write data, error = \(error)")
            resetState()
            return
        }
        
        // write pending chunks
        writeNextPendingChunk()
    }
    
}