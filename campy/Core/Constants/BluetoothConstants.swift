//
//  BluetoothConstants.swift
//  campy
//
//  Constants for Bluetooth Low Energy communication
//

import Foundation
import CoreBluetooth

struct BluetoothConstants {
    // Service UUID
    static let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    
    // Characteristics
    static let sessionCharacteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")
    static let controlCharacteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567892")
    static let heartbeatCharacteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567893")
    
    // Configuration
    static let heartbeatInterval: TimeInterval = 1.0
    static let heartbeatTimeout: TimeInterval = 3.0
    static let localNamePrefix = "Campy-"
}
