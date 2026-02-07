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
    private let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    private let characteristicUUID = CBUUID(string: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")

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
    private var characteristic: CBMutableCharacteristic?

    // Session data
    private var currentSession: Session?
    private var messageBuffer = Data()

    // Callbacks
    var onSessionDiscovered: ((NearbySession) -> Void)?
    var onParticipantJoined: ((SessionParticipant) -> Void)?
    var onParticipantLeft: ((UUID) -> Void)?
    var onGameStarted: ((Session?) -> Void)?
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

        // Create characteristic for data transfer
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )

        // Create service
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic!]

        peripheralManager.add(service)

        // Start advertising
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Campy-\(session.id.uuidString.prefix(8))"
        ]
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        isAdvertising = false
    }

    func broadcastGameStart(session: Session) {
        currentSession = session
        let payload = try? JSONEncoder().encode(session)
        let message = BluetoothMessage(type: .gameStart, senderId: localPeerId, payload: payload)
        broadcastMessage(message)
    }

    func broadcastMessage(_ message: BluetoothMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let characteristic = characteristic else { return }

        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }

    // MARK: - Client Mode (Central)

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        discoveredSessions.removeAll()
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
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

    // MARK: - Message Handling

    func reportLoss(participantId: UUID) {
        let payload = try? JSONEncoder().encode(participantId)
        let message = BluetoothMessage(type: .loss, senderId: localPeerId, payload: payload)

        if isAdvertising {
            broadcastMessage(message)
        } else if let peripheral = connectedPeripheral,
                  let characteristic = peripheral.services?.first?.characteristics?.first {
            let data = try? JSONEncoder().encode(message)
            peripheral.writeValue(data ?? Data(), for: characteristic, type: .withResponse)
        }
    }

    private func handleReceivedMessage(_ message: BluetoothMessage) {
        switch message.type {
        case .sessionInfo:
            if let payload = message.payload,
               let session = try? JSONDecoder().decode(Session.self, from: payload) {
                currentSession = session
                onSessionReceived?(session)
            }

        case .participantJoined:
            if let payload = message.payload,
               let participant = try? JSONDecoder().decode(SessionParticipant.self, from: payload) {
                onParticipantJoined?(participant)
            }

        case .participantLeft:
            if let payload = message.payload,
               let participantId = try? JSONDecoder().decode(UUID.self, from: payload) {
                onParticipantLeft?(participantId)
            }

        case .gameStart:
            var session: Session?
            if let payload = message.payload {
                session = try? JSONDecoder().decode(Session.self, from: payload)
            }
            onGameStarted?(session)

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
                onGameEnded?(participantId)
            }

        case .ping, .pong:
            break
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Extract session info from advertisement
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              name.hasPrefix("Campy-") else { return }

        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)

            let session = NearbySession(
                id: UUID(),
                hostName: "Player",
                hostPeerId: peripheral.identifier.uuidString,
                durationMinutes: 15,
                betAmount: 15,
                participantCount: 1,
                signalStrength: RSSI.intValue
            )
            discoveredSessions.append(session)
            onSessionDiscovered?(session)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
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
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)

                // Request session info
                let message = BluetoothMessage(type: .ping, senderId: localPeerId)
                if let data = try? JSONEncoder().encode(message) {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        if let message = try? JSONDecoder().decode(BluetoothMessage.self, from: data) {
            handleReceivedMessage(message)
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
            if let data = request.value,
               let message = try? JSONDecoder().decode(BluetoothMessage.self, from: data) {
                handleReceivedMessage(message)

                // If ping, respond with session info
                if message.type == .ping, let session = currentSession {
                    let payload = try? JSONEncoder().encode(session)
                    let response = BluetoothMessage(type: .sessionInfo, senderId: localPeerId, payload: payload)
                    broadcastMessage(response)
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedPeers.append(central.identifier.uuidString)

        // Send session info to new subscriber
        if let session = currentSession {
            let payload = try? JSONEncoder().encode(session)
            let message = BluetoothMessage(type: .sessionInfo, senderId: localPeerId, payload: payload)
            broadcastMessage(message)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        connectedPeers.removeAll { $0 == central.identifier.uuidString }
    }
}
