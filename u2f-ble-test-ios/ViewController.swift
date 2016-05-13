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
    
    private lazy var bluetoothManager: BluetoothManager = {
        let manager = BluetoothManager()
        manager.onStateChanged = self.handleStateChanged
        manager.onDebugMessage = self.handleDebugMessage
        return manager
    }()

    @IBAction func scanForDevice(sender: AnyObject) {
        bluetoothManager.scanForDevice()
    }
    
    @IBAction func stopSession(sender: AnyObject) {
        bluetoothManager.stopSession()
    }
    
    private func handleStateChanged(manager: BluetoothManager, state: BluetoothManagerState) {
        updateUI()
    }
    
    private func handleDebugMessage(manager: BluetoothManager, message: String) {
        textView.text = textView.text + "\(message)\n"
        let range = NSMakeRange(textView.text.characters.count - 1, 1)
        textView.scrollRangeToVisible(range)
    }
    
    private func updateUI() {
        bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        stateLabel.text = bluetoothManager.state.rawValue
        scanButton.enabled = bluetoothManager.state == .Disconnected
        stopButton.enabled = bluetoothManager.state == .Connecting || bluetoothManager.state == .Connected || bluetoothManager.state == .Scanning
        nameLabel.hidden = bluetoothManager.state != .Connected
        nameLabel.text = bluetoothManager.deviceName
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.layoutManager.allowsNonContiguousLayout = false
        updateUI()
    }

}

