//
//  BluetoothManager.swift
//  campy
//
//  Manages Bluetooth peer-to-peer connections for multiplayer sessions
//

import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Bluetooth Message Types
enum BluetoothMessageType: String, Codable {
    case sessionInfo
    case participantJoined
    case participantLeft
    case gameStart
    case gameEnd
    case loss
    case ping
    case pong
}

struct BluetoothMessage: Codable {
    let type: BluetoothMessageType
    let senderId: String
    let payload: Data?
    let timestamp: Date

    init(type: BluetoothMessageType, senderId: String, payload: Data? = nil) {
        self.type = type
        self.senderId = senderId
        self.payload = payload
        self.timestamp = Date()
    }
}

// MARK: - Bluetooth Manager
@Observable
class BluetoothManager: NSObject {
    // State
    private(set) var isBluetoothEnabled = false
    private(set) var isAdvertising = false
    private(set) var isScanning = false
    private(set) var connectedPeers: [String] = []
    private(set) var discoveredSessions: [NearbySession] = []

    // Identifiers
    var localPeerId: String {
        if let id = UserDefaults.standard.string(forKey: "bluetoothPeerId") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "bluetoothPeerId")
        return newId
    }

    // Core Bluetooth
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var discoveredPeripherals: [CBPeripheral] = []
    private var connectedPeripheral: CBPeripheral?
    
    // Characteristics
    private var sessionCharacteristic: CBMutableCharacteristic?
    private var controlCharacteristic: CBMutableCharacteristic?
    private var heartbeatCharacteristic: CBMutableCharacteristic?

    // Session data
    private var currentSession: Session?
    private var heartbeatTimer: Timer?
    private var lastHeartbeatTime: Date?

    // Callbacks
    var onSessionDiscovered: ((NearbySession) -> Void)?
    var onParticipantJoined: ((SessionParticipant) -> Void)?
    var onParticipantLeft: ((UUID) -> Void)?
    var onGameStarted: (() -> Void)?
    var onGameEnded: ((UUID?) -> Void)?
    var onSessionReceived: ((Session) -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - Host Mode (Peripheral)

    func startAdvertising(session: Session) {
        guard peripheralManager.state == .poweredOn else { return }

        currentSession = session

        // 1. Session Characteristic (Read/Notify)
        sessionCharacteristic = CBMutableCharacteristic(
            type: BluetoothConstants.sessionCharacteristicUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        
        // 2. Control Characteristic (Write/Notify)
        controlCharacteristic = CBMutableCharacteristic(
            type: BluetoothConstants.controlCharacteristicUUID,
            properties: [.write, .notify],
            value: nil,
            permissions: [.writeable]
        )
        
        // 3. Heartbeat Characteristic (Notify)
        heartbeatCharacteristic = CBMutableCharacteristic(
            type: BluetoothConstants.heartbeatCharacteristicUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )

        // Create service
        let service = CBMutableService(type: BluetoothConstants.serviceUUID, primary: true)
        service.characteristics = [
            sessionCharacteristic!,
            controlCharacteristic!,
            heartbeatCharacteristic!
        ]

        peripheralManager.add(service)

        // Encode session info into local name for discovery
        // Format: CMP|HostName|Duration|Bet|Count
        // Note: Bluetooth Local Name is limited in length, so we keep it short
        let hostName = session.participants.first(where: { $0.isHost })?.displayName ?? "Host"
        let safeHostName = String(hostName.prefix(10))
        let localName = "CMP|\(safeHostName)|\(session.durationMinutes)|\(session.betAmount)|\(session.participants.count)"
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BluetoothConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: localName
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        
        startHeartbeat()
    }

    func stopAdvertising() {
        stopHeartbeat()
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        isAdvertising = false
    }

        func broadcastGameStart() {

            guard currentSession != nil else { return }

            let message = BluetoothMessage(type: .gameStart, senderId: localPeerId)

            broadcastControlMessage(message)

        }
    
    func broadcastGameEnd(loserId: UUID?) {
        let payload = try? JSONEncoder().encode(loserId)
        let message = BluetoothMessage(type: .gameEnd, senderId: localPeerId, payload: payload)
        broadcastControlMessage(message)
    }
    
    private func broadcastControlMessage(_ message: BluetoothMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let characteristic = controlCharacteristic else { return }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
    
    private func updateSessionInfo() {
        guard let session = currentSession,
              let data = try? JSONEncoder().encode(session),
              let characteristic = sessionCharacteristic else { return }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }

    // MARK: - Client Mode (Central)

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        discoveredSessions.removeAll()
        centralManager.scanForPeripherals(withServices: [BluetoothConstants.serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        isScanning = true
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    func connectToHost(peerId: String) {
        guard let peripheral = discoveredPeripherals.first(where: {
            $0.identifier.uuidString == peerId
        }) else { return }

        stopScanning()
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
    }

    // MARK: - Message Handling & Heartbeat

    func reportLoss(participantId: UUID) {
        let payload = try? JSONEncoder().encode(participantId)
        let message = BluetoothMessage(type: .loss, senderId: localPeerId, payload: payload)

        if isAdvertising {
            // Host reporting loss
            broadcastControlMessage(message)
            onGameEnded?(participantId)
        } else if let peripheral = connectedPeripheral,
                  let characteristic = peripheral.services?.first?.characteristics?.first(where: { $0.uuid == BluetoothConstants.controlCharacteristicUUID }) {
            // Client reporting loss to host
            let data = try? JSONEncoder().encode(message)
            peripheral.writeValue(data ?? Data(), for: characteristic, type: .withResponse)
        }
    }

    private func handleReceivedControlMessage(_ message: BluetoothMessage) {
        switch message.type {
        case .participantJoined:
            if let payload = message.payload,
               let participant = try? JSONDecoder().decode(SessionParticipant.self, from: payload) {
                onParticipantJoined?(participant)
                // Host updates session info for everyone
                updateSessionInfo()
            }

        case .participantLeft:
            if let payload = message.payload,
               let participantId = try? JSONDecoder().decode(UUID.self, from: payload) {
                onParticipantLeft?(participantId)
                updateSessionInfo()
            }

        case .gameStart:
            onGameStarted?()

        case .gameEnd:
            if let payload = message.payload {
                let loserId = try? JSONDecoder().decode(UUID.self, from: payload)
                onGameEnded?(loserId)
            } else {
                onGameEnded?(nil)
            }

        case .loss:
            if let payload = message.payload,
               let participantId = try? JSONDecoder().decode(UUID.self, from: payload) {
                // Host received loss report
                onGameEnded?(participantId)
                // Broadcast to others
                broadcastGameEnd(loserId: participantId)
            }

        default:
            break
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: BluetoothConstants.heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self, let characteristic = self.heartbeatCharacteristic else { return }
            let data = Data([0x01]) // Simple ping
            self.peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Parse dynamic advertisement data
        // Format: CMP|HostName|Duration|Bet|Count
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              name.hasPrefix("CMP|") else { return }

        let components = name.components(separatedBy: "|")
        guard components.count >= 5 else { return }
        
        let hostName = components[1]
        let duration = Int(components[2]) ?? 15
        let bet = Int(components[3]) ?? 15
        let count = Int(components[4]) ?? 1
        
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)

            let session = NearbySession(
                id: UUID(), // We don't know the exact UUID yet, but that's okay for discovery
                hostName: hostName,
                hostPeerId: peripheral.identifier.uuidString,
                durationMinutes: duration,
                betAmount: bet,
                participantCount: count,
                signalStrength: RSSI.intValue
            )
            discoveredSessions.append(session)
            onSessionDiscovered?(session)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([BluetoothConstants.serviceUUID])
        connectedPeers.append(peripheral.identifier.uuidString)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeers.removeAll { $0 == peripheral.identifier.uuidString }
        connectedPeripheral = nil

        // Report disconnection as loss
        if let session = currentSession,
           let participant = session.participants.first(where: { $0.peerId == peripheral.identifier.uuidString }) {
            onParticipantLeft?(participant.id)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == BluetoothConstants.serviceUUID {
                peripheral.discoverCharacteristics([
                    BluetoothConstants.sessionCharacteristicUUID,
                    BluetoothConstants.controlCharacteristicUUID,
                    BluetoothConstants.heartbeatCharacteristicUUID
                ], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic) // Initial read
            } else if characteristic.uuid == BluetoothConstants.controlCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                // Send join request
                // Note: We need the actual participant object here.
                // Assuming GameManager will call a method to send this after connection is established.
            } else if characteristic.uuid == BluetoothConstants.heartbeatCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case BluetoothConstants.sessionCharacteristicUUID:
            if let session = try? JSONDecoder().decode(Session.self, from: data) {
                currentSession = session
                onSessionReceived?(session)
            }
            
        case BluetoothConstants.controlCharacteristicUUID:
            if let message = try? JSONDecoder().decode(BluetoothMessage.self, from: data) {
                handleReceivedControlMessage(message)
            }
            
        case BluetoothConstants.heartbeatCharacteristicUUID:
            lastHeartbeatTime = Date()
            
        default:
            break
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        isBluetoothEnabled = peripheral.state == .poweredOn
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == BluetoothConstants.controlCharacteristicUUID,
               let data = request.value,
               let message = try? JSONDecoder().decode(BluetoothMessage.self, from: data) {
                
                handleReceivedControlMessage(message)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedPeers.append(central.identifier.uuidString)

        // If session char, send current session
        if characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID,
           let session = currentSession,
           let data = try? JSONEncoder().encode(session),
           let sessionChar = self.sessionCharacteristic {
             peripheralManager.updateValue(data, for: sessionChar, onSubscribedCentrals: [central])
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID {
            connectedPeers.removeAll { $0 == central.identifier.uuidString }
        }
    }
    
    // Read request for Session Characteristic
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID,
           let session = currentSession,
           let data = try? JSONEncoder().encode(session) {
            
            if request.offset > data.count {
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            
            request.value = data.subdata(in: request.offset..<data.count)
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }
}
