//
//  ArduinoCommunicationManager.swift
//  JumpAnalysis
//
//  Created by Lukas Welte on 19.01.15.
//  Copyright (c) 2015 Lukas Welte. All rights reserved.
//

import Foundation

private let _SharedInstance = ArduinoCommunicationManager()

class ArduinoCommunicationManager: NSObject, BLEDiscoveryDelegate, BLEServiceDelegate, BLEServiceDataDelegate {
    
    let numberOfRequiredSensors: Int = 1
    var shouldAutomaticallyReconnect = false
    
    class var sharedInstance: ArduinoCommunicationManager {
        return _SharedInstance
    }

    var sensorDataDelegate: SensorDataDelegate? = nil

    override init() {
        super.init()
        let sharedInstance = BLEDiscovery.sharedInstance()
        sharedInstance.discoveryDelegate = self
        sharedInstance.peripheralDelegate = self
        
        sharedInstance.startScanningForSupportedUUIDs()
    }
    
    func isAbleToReceiveSensorData() -> Bool {
        let foundPeripherals = BLEDiscovery.sharedInstance().foundPeripherals.count
        NSLog("Found %d Peripherals", foundPeripherals)
        return foundPeripherals == numberOfRequiredSensors
    }
    
    func connectToPeripherals() {
        let sharedInstance = BLEDiscovery.sharedInstance()
        for object in sharedInstance.foundPeripherals {
            if let peripheral = object as? CBPeripheral {
                sharedInstance.connectPeripheral(peripheral)
            }
        }
    }
    
    func disconnectFromPeripherals() {
        NSLog("Disconnect from Peripherals ...")
        BLEDiscovery.sharedInstance().disconnectConnectedPeripherals()
    }
    
    func startReceivingSensorData() {
        self.shouldAutomaticallyReconnect = true
        
        self.connectToPeripherals()
    }
    
    func stopReceivingSensorData() {
        self.shouldAutomaticallyReconnect = false
        
        self.disconnectFromPeripherals()
    }
    
//Mark: BLEDiscovery
    
    func discoveryDidRefresh() {
        NSLog("Discovered did refresh")
        if (self.isAbleToReceiveSensorData()) {
            self.connectToPeripherals()
        }
    }
    
    func peripheralDiscovered(peripheral: CBPeripheral!) {
        NSLog("Discovered Peripherial: %@", peripheral)
        if (self.isAbleToReceiveSensorData()) {
            self.connectToPeripherals()
        }
    }
    
    func discoveryStatePoweredOff() {
        NSLog("Discovery State Powerered Off ...")
    }
    
    
//MARK: BLEServiceProtocol
    
    func bleServiceDidConnect(service: BLEService!) {
        service.delegate = self
        service.dataDelegate = self
        
        NSLog("bleServiceDidConnect:%@", service);
    }
    
    func bleServiceDidDisconnect(service: BLEService!) {
        NSLog("bleServiceDidDisconnect:%@", service);
    }
    
    func bleServiceIsReady(service: BLEService!) {
        NSLog("bleServiceIsReady:%@", service);
    }
    
    func bleServiceDidReset() {
        NSLog("bleServiceDidReset");
    }
    
    func reportMessage(message: String!) {
        println("BLE Message: \(message)")
    }
    
//MARK: BLEServiceData Delegate
    
    func didReceiveData(data: UnsafeMutablePointer<UInt8>, length: Int) {
        if (length == 14 && self.sensorDataDelegate != nil) {
            let sensorTimestampInMilliseconds =  transformReceivedUIntsToInt([data[12], data[13]])
            
            let linearAccelerationX = transformReceivedBytesIntoInt([data[0], data[1]])
            let linearAccelerationY = transformReceivedBytesIntoInt([data[2], data[3]])
            let linearAccelerationZ = transformReceivedBytesIntoInt([data[4], data[5]])
            let linearAcceleration = LinearAcceleration(x: linearAccelerationX, y: linearAccelerationY, z: linearAccelerationZ)
            
            let rawAccelerationX = transformReceivedBytesIntoInt([data[6], data[7]])
            let rawAccelerationY = transformReceivedBytesIntoInt([data[8], data[9]])
            let rawAccelerationZ = transformReceivedBytesIntoInt([data[10], data[11]])
            let rawAcceleration = RawAcceleration(x: rawAccelerationX, y: rawAccelerationY, z: rawAccelerationZ)
            
            let sensorData = SensorData(sensorTimeStamp: sensorTimestampInMilliseconds, rawAcceleration: rawAcceleration, linearAcceleration: linearAcceleration)

            if let delegate = self.sensorDataDelegate {
                delegate.didReceiveData(sensorData)
            }
        }
    }
    
    func transformReceivedUIntsToInt(inputData: [UInt8]) -> Int {
        let data = NSData(bytes: inputData, length: inputData.count)
        
        var u16 : UInt16 = 0 ;
        data.getBytes(&u16)
        
        return Int(u16)
    }
    
    func transformReceivedBytesIntoInt(inputData: [UInt8]) -> Int {
        return transformReceivedUIntsToInt(inputData) - 32767
    }
    
}