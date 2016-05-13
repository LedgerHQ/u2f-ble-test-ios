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
    
    private lazy var bluetoothManager: BluetoothManager = {
        let manager = BluetoothManager()
        manager.onStateChanged = self.handleStateChanged
        return manager
    }()

    @IBAction func scanForDevice(sender: AnyObject) {
        bluetoothManager.scanForDevice()
    }
    
    @IBAction func stopSession(sender: AnyObject) {
        bluetoothManager.stopSession()
    }
    
    private func handleStateChanged(manager: BluetoothManager, state: BluetoothManagerState) {
        print("STATE = \(state)")
        updateUI()
    }
    
    private func updateUI() {
        bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        stateLabel.text = bluetoothManager.state.rawValue
        scanButton.enabled = bluetoothManager.state == .Disconnected
        stopButton.enabled = bluetoothManager.state == .Connecting || bluetoothManager.state == .Connected || bluetoothManager.state == .Scanning
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }

}

