//
//  ViewController.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var scanButton: UIButton!
    @IBOutlet private weak var stopButton: UIButton!
    @IBOutlet private weak var stateLabel: UILabel!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var textView: UITextView!
    @IBOutlet var actionButtons: [UIButton]!
    
    private lazy var bluetoothManager: BluetoothManager = {
        let manager = BluetoothManager()
        manager.onStateChanged = self.handleStateChanged
        manager.onDebugMessage = self.handleDebugMessage
        manager.onReceivedAPDU = self.handleReceivedAPDU
        return manager
    }()
    private var useInvalidApplicationParameter = true
    private var useInvalidKeyHandle = true
    private var currentAPDU: APDUType? = nil
    private var registerAPDU: RegisterAPDU? = nil
    
    // MARK: Actions
    
    @IBAction func scanForDevice() {
        bluetoothManager.scanForDevice()
    }
    
    @IBAction func stopSession() {
        bluetoothManager.stopSession()
    }
    
    @IBAction func sendRegister() {
        var challenge: [UInt8] = []
        var applicationParameter: [UInt8] = []
        
        for i in 0..<32 {
            challenge.append(UInt8(i))
            applicationParameter.append(UInt8(i) | 0x80)
        }
        let challengeData = NSData(bytes: &challenge, length: 32)
        let applicationParameterData = NSData(bytes: &applicationParameter, length: 32)
        
        if let APDU = RegisterAPDU(challenge: challengeData, applicationParameter: applicationParameterData) {
            APDU.onDebugMessage = self.handleAPDUMessage
            let data = APDU.buildRequest()
            bluetoothManager.exchangeAPDU(data)
            currentAPDU = APDU
        }
        else {
            appendLogMessage("Unable to build REGISTER APDU")
        }
    }
    
    @IBAction func sendAuthenticate() {
        sendAuthenticate(checkOnly: false)
    }
    
    @IBAction func sendAuthenticateCheck() {
        sendAuthenticate(checkOnly: true)
    }
    
    private func sendAuthenticate(checkOnly checkOnly: Bool) {
        guard
            let registerAPDU = registerAPDU,
            let originalKeyHandle = registerAPDU.keyHandle else {
            appendLogMessage("Unable to build AUTHENTICATE APDU, not yet REGISTERED")
            return
        }

        var challenge: [UInt8] = []
        var applicationParameter: [UInt8] = []
        let keyHandleData: NSData
        
        for i in 0..<32 {
            challenge.append(UInt8(i) | 0x10)
            applicationParameter.append(UInt8(i) | 0x80)
        }
        if useInvalidApplicationParameter {
            applicationParameter[0] = 0xFF
        }
        if useInvalidKeyHandle {
            let data = NSMutableData(data: originalKeyHandle)
            data.replaceBytesInRange(NSMakeRange(0, 2), withBytes: [0xFF, 0xFF] as [UInt8], length: 2)
            data.replaceBytesInRange(NSMakeRange(data.length - 1, 1), withBytes: [0xFF] as [UInt8], length: 1)
            keyHandleData = data
        }
        else {
            keyHandleData = originalKeyHandle
        }
        let challengeData = NSData(bytes: &challenge, length: 32)
        let applicationParameterData = NSData(bytes: &applicationParameter, length: 32)
        
        if let APDU = AuthenticateAPDU(registerAPDU: registerAPDU, challenge: challengeData, applicationParameter: applicationParameterData, keyHandle: keyHandleData, checkOnly: checkOnly) {
            APDU.onDebugMessage = self.handleAPDUMessage
            let data = APDU.buildRequest()
            bluetoothManager.exchangeAPDU(data)
            currentAPDU = APDU
        }
        else {
            appendLogMessage("Unable to build AUTHENTICATE APDU")
        }
    }
    
    @IBAction func toggleApplicationParameter() {
        useInvalidApplicationParameter = !useInvalidApplicationParameter
        appendLogMessage("Use invalid application parameter = \(useInvalidApplicationParameter)")
    }
    
    @IBAction func toggleKeyHandle() {
        useInvalidKeyHandle = !useInvalidKeyHandle
        appendLogMessage("Use invalid key handle = \(useInvalidKeyHandle)")
    }
    
    @IBAction func clearLogs() {
        textView.text = ""
    }
    
    // MARK: BluetoothManager
    
    private func handleStateChanged(manager: BluetoothManager, state: BluetoothManagerState) {
        updateUI()
        
        if state == .Disconnected {
            currentAPDU = nil
        }
    }
    
    private func handleDebugMessage(manager: BluetoothManager, message: String) {
        appendLogMessage(message)
    }
    
    private func handleReceivedAPDU(manager: BluetoothManager, data: NSData) {
        if let success = currentAPDU?.parseResponse(data) where success {
            appendLogMessage("Successfully parsed APDU response of kind \(currentAPDU)")
            if currentAPDU is RegisterAPDU {
                registerAPDU = currentAPDU as? RegisterAPDU
            }
        }
        else {
            appendLogMessage("Failed to parse APDU response of kind \(currentAPDU.dynamicType)")
        }
        currentAPDU = nil
    }
    
    // MARK: APDU
    
    private func handleAPDUMessage(APDU: APDUType, message: String) {
        appendLogMessage(message)
    }
    
    // MARK: User interface
    
    private func appendLogMessage(message: String) {
        textView.text = textView.text + "- \(message)\n"
        let range = NSMakeRange(textView.text.characters.count - 1, 1)
        UIView.setAnimationsEnabled(false)
        textView.scrollRangeToVisible(range)
        UIView.setAnimationsEnabled(true)
    }
    
    private func updateUI() {
        bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        stateLabel.text = bluetoothManager.state.rawValue
        scanButton.enabled = bluetoothManager.state == .Disconnected
        stopButton.enabled = bluetoothManager.state == .Connecting || bluetoothManager.state == .Connected || bluetoothManager.state == .Scanning
        nameLabel.hidden = bluetoothManager.state != .Connected
        nameLabel.text = bluetoothManager.deviceName
        actionButtons.forEach() { $0.enabled = bluetoothManager.state == .Connected }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.layoutManager.allowsNonContiguousLayout = false
        updateUI()
        toggleApplicationParameter()
        toggleKeyHandle()
    }

}

