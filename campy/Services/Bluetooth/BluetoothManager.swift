//
//  BluetoothManager.swift
//  campy
//
//  Manages Bluetooth peer-to-peer connections for multiplayer sessions
//

import SwiftUI
import CoreBluetooth
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "campy", category: "Bluetooth")

// MARK: - Bluetooth Errors
enum BluetoothError: LocalizedError {
    case bluetoothPoweredOff
    case bluetoothUnsupported
    case advertisingFailed(String)
    case scanningFailed(String)
    case connectionFailed(String)
    case connectionTimeout
    case messageEncodingFailed(String)
    case messageDecodingFailed(String)
    case messageDeliveryFailed(String)
    case heartbeatTimeout
    case sessionDataTooLarge
    case peripheralNotFound
    case characteristicNotFound

    var errorDescription: String? {
        switch self {
        case .bluetoothPoweredOff:
            return "Bluetooth is turned off. Please enable Bluetooth in Settings."
        case .bluetoothUnsupported:
            return "This device does not support Bluetooth Low Energy."
        case .advertisingFailed(let detail):
            return "Failed to advertise session: \(detail)"
        case .scanningFailed(let detail):
            return "Failed to scan for sessions: \(detail)"
        case .connectionFailed(let detail):
            return "Failed to connect: \(detail)"
        case .connectionTimeout:
            return "Connection timed out. Please try again."
        case .messageEncodingFailed(let detail):
            return "Failed to send message: \(detail)"
        case .messageDecodingFailed(let detail):
            return "Failed to read message: \(detail)"
        case .messageDeliveryFailed(let detail):
            return "Message delivery failed: \(detail)"
        case .heartbeatTimeout:
            return "Lost connection to the other device."
        case .sessionDataTooLarge:
            return "Session data is too large to transmit."
        case .peripheralNotFound:
            return "Could not find the host device. Please try scanning again."
        case .characteristicNotFound:
            return "Could not communicate with the host device."
        }
    }
}

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
    private var heartbeatTimeoutTimer: Timer?
    private var connectionTimeoutTimer: Timer?

    // Callbacks
    var onSessionDiscovered: ((NearbySession) -> Void)?
    var onParticipantJoined: ((SessionParticipant) -> Void)?
    var onParticipantLeft: ((UUID) -> Void)?
    var onGameStarted: (() -> Void)?
    var onGameEnded: ((UUID?) -> Void)?
    var onSessionReceived: ((Session) -> Void)?
    var onError: ((BluetoothError) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - Host Mode (Peripheral)

    func startAdvertising(session: Session) {
        guard peripheralManager.state == .poweredOn else {
            logger.error("Cannot advertise: Bluetooth is not powered on (state: \(self.peripheralManager.state.rawValue))")
            onError?(.bluetoothPoweredOff)
            return
        }

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
        let advertisementData = buildAdvertisementData(for: session)

        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        logger.info("Started advertising session: host=\(session.participants.first(where: { $0.isHost })?.displayName ?? "Unknown"), duration=\(session.durationMinutes)min, bet=\(session.betAmount)")

        startHeartbeat()
    }

    func stopAdvertising() {
        stopHeartbeat()
        stopHeartbeatTimeoutCheck()
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        isAdvertising = false
        logger.info("Stopped advertising")
    }

    func broadcastGameStart() {
        guard currentSession != nil else {
            logger.warning("broadcastGameStart called with no current session")
            return
        }

        let message = BluetoothMessage(type: .gameStart, senderId: localPeerId)
        broadcastControlMessage(message)
    }

    func broadcastGameEnd(loserId: UUID?) {
        do {
            let payload = try JSONEncoder().encode(loserId)
            let message = BluetoothMessage(type: .gameEnd, senderId: localPeerId, payload: payload)
            broadcastControlMessage(message)
        } catch {
            logger.error("Failed to encode game end payload: \(error.localizedDescription)")
            onError?(.messageEncodingFailed("game end loserId"))
        }
    }

    private func broadcastControlMessage(_ message: BluetoothMessage) {
        guard let characteristic = controlCharacteristic else {
            logger.error("Cannot broadcast: control characteristic not available")
            onError?(.characteristicNotFound)
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
            if !success {
                logger.warning("updateValue returned false for control message type=\(message.type.rawValue) — will retry when peripheralManagerIsReady is called")
            } else {
                logger.debug("Broadcast control message: \(message.type.rawValue)")
            }
        } catch {
            logger.error("Failed to encode control message: \(error.localizedDescription)")
            onError?(.messageEncodingFailed(message.type.rawValue))
        }
    }

    private func updateSessionInfo() {
        guard let session = currentSession,
              let characteristic = sessionCharacteristic else {
            logger.warning("Cannot update session info: missing session or characteristic")
            return
        }

        do {
            let data = try JSONEncoder().encode(session)
            let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
            if !success {
                logger.warning("updateValue returned false for session info — will retry when peripheralManagerIsReady is called")
            }
        } catch {
            logger.error("Failed to encode session info: \(error.localizedDescription)")
            onError?(.messageEncodingFailed("session info"))
        }
    }

    /// Re-advertise with updated session data (e.g., after participant count changes)
    private func refreshAdvertisement() {
        guard isAdvertising, let session = currentSession else { return }
        peripheralManager.stopAdvertising()
        let advertisementData = buildAdvertisementData(for: session)
        peripheralManager.startAdvertising(advertisementData)
        logger.debug("Refreshed advertisement data with \(session.participants.count) participants")
    }

    private func buildAdvertisementData(for session: Session) -> [String: Any] {
        let hostName = session.participants.first(where: { $0.isHost })?.displayName ?? "Host"
        // Keep host name short to fit within BLE local name limits (~28 usable bytes)
        let safeHostName = String(hostName.prefix(8))
        let localName = "CMP|\(safeHostName)|\(session.durationMinutes)|\(session.betAmount)|\(session.participants.count)"

        return [
            CBAdvertisementDataServiceUUIDsKey: [BluetoothConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: localName
        ]
    }

    // MARK: - Client Mode (Central)

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.error("Cannot scan: Bluetooth is not powered on (state: \(self.centralManager.state.rawValue))")
            onError?(.bluetoothPoweredOff)
            return
        }

        discoveredSessions.removeAll()
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: [BluetoothConstants.serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        isScanning = true
        logger.info("Started scanning for sessions")
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        logger.info("Stopped scanning")
    }

    func connectToHost(peerId: String) {
        guard let peripheral = discoveredPeripherals.first(where: {
            $0.identifier.uuidString == peerId
        }) else {
            logger.error("Cannot connect: peripheral \(peerId) not found in discovered list")
            onError?(.peripheralNotFound)
            return
        }

        stopScanning()
        centralManager.connect(peripheral, options: nil)
        logger.info("Connecting to host peripheral: \(peerId)")

        // Start connection timeout
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.connectedPeripheral == nil {
                logger.error("Connection timed out for peripheral: \(peerId)")
                self.centralManager.cancelPeripheralConnection(peripheral)
                self.onError?(.connectionTimeout)
            }
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        stopHeartbeatTimeoutCheck()
    }

    // MARK: - Message Handling & Heartbeat

    func reportLoss(participantId: UUID) {
        do {
            let payload = try JSONEncoder().encode(participantId)
            let message = BluetoothMessage(type: .loss, senderId: localPeerId, payload: payload)

            if isAdvertising {
                // Host reporting loss
                broadcastControlMessage(message)
                onGameEnded?(participantId)
            } else if let peripheral = connectedPeripheral {
                guard let characteristic = peripheral.services?
                    .flatMap({ $0.characteristics ?? [] })
                    .first(where: { $0.uuid == BluetoothConstants.controlCharacteristicUUID }) else {
                    logger.error("Cannot report loss: control characteristic not found on peripheral")
                    onError?(.characteristicNotFound)
                    return
                }

                let data = try JSONEncoder().encode(message)
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
                logger.info("Sent loss report for participant: \(participantId)")
            } else {
                logger.error("Cannot report loss: not advertising and no connected peripheral")
                onError?(.connectionFailed("No active connection to report loss"))
            }
        } catch {
            logger.error("Failed to encode loss report: \(error.localizedDescription)")
            onError?(.messageEncodingFailed("loss report"))
        }
    }

    private func handleReceivedControlMessage(_ message: BluetoothMessage) {
        logger.debug("Received control message: \(message.type.rawValue) from \(message.senderId)")

        switch message.type {
        case .participantJoined:
            guard let payload = message.payload else {
                logger.error("participantJoined message missing payload")
                onError?(.messageDecodingFailed("participantJoined: missing payload"))
                return
            }
            do {
                let participant = try JSONDecoder().decode(SessionParticipant.self, from: payload)
                onParticipantJoined?(participant)
                // Host updates session info for everyone and refreshes advertisement
                currentSession?.participants.append(participant)
                updateSessionInfo()
                refreshAdvertisement()
            } catch {
                logger.error("Failed to decode participantJoined: \(error.localizedDescription)")
                onError?(.messageDecodingFailed("participantJoined"))
            }

        case .participantLeft:
            guard let payload = message.payload else {
                logger.error("participantLeft message missing payload")
                onError?(.messageDecodingFailed("participantLeft: missing payload"))
                return
            }
            do {
                let participantId = try JSONDecoder().decode(UUID.self, from: payload)
                onParticipantLeft?(participantId)
                currentSession?.participants.removeAll { $0.id == participantId }
                updateSessionInfo()
                refreshAdvertisement()
            } catch {
                logger.error("Failed to decode participantLeft: \(error.localizedDescription)")
                onError?(.messageDecodingFailed("participantLeft"))
            }

        case .gameStart:
            onGameStarted?()

        case .gameEnd:
            if let payload = message.payload {
                do {
                    let loserId = try JSONDecoder().decode(UUID.self, from: payload)
                    onGameEnded?(loserId)
                } catch {
                    logger.error("Failed to decode gameEnd loserId: \(error.localizedDescription)")
                    onError?(.messageDecodingFailed("gameEnd"))
                    onGameEnded?(nil)
                }
            } else {
                onGameEnded?(nil)
            }

        case .loss:
            guard let payload = message.payload else {
                logger.error("loss message missing payload")
                onError?(.messageDecodingFailed("loss: missing payload"))
                return
            }
            do {
                let participantId = try JSONDecoder().decode(UUID.self, from: payload)
                // Host received loss report
                onGameEnded?(participantId)
                // Broadcast to others
                broadcastGameEnd(loserId: participantId)
            } catch {
                logger.error("Failed to decode loss participantId: \(error.localizedDescription)")
                onError?(.messageDecodingFailed("loss"))
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

    private func startHeartbeatTimeoutCheck() {
        lastHeartbeatTime = Date()
        heartbeatTimeoutTimer = Timer.scheduledTimer(withTimeInterval: BluetoothConstants.heartbeatTimeout, repeats: true) { [weak self] _ in
            guard let self = self, let lastTime = self.lastHeartbeatTime else { return }
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed > BluetoothConstants.heartbeatTimeout {
                logger.warning("Heartbeat timeout: no heartbeat for \(String(format: "%.1f", elapsed))s")
                self.onError?(.heartbeatTimeout)
                self.stopHeartbeatTimeoutCheck()
            }
        }
    }

    private func stopHeartbeatTimeoutCheck() {
        heartbeatTimeoutTimer?.invalidate()
        heartbeatTimeoutTimer = nil
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
        logger.info("Central manager state updated: \(central.state.rawValue) (poweredOn=\(central.state == .poweredOn))")

        if central.state != .poweredOn && central.state != .unknown {
            onError?(.bluetoothPoweredOff)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {

        // Parse advertisement data
        // Format: CMP|HostName|Duration|Bet|Count
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              name.hasPrefix("CMP|") else { return }

        let components = name.components(separatedBy: "|")
        guard components.count >= 5 else {
            logger.warning("Malformed advertisement name (expected 5 components): \(name)")
            return
        }

        let hostName = components[1]
        let duration = Int(components[2]) ?? 15
        let bet = Int(components[3]) ?? 15
        let count = Int(components[4]) ?? 1

        // Update existing session if we've already seen this peripheral, otherwise add new
        if let existingIndex = discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            // Update the stored peripheral reference
            discoveredPeripherals[existingIndex] = peripheral

            // Update existing NearbySession with fresh advertisement data
            if let sessionIndex = discoveredSessions.firstIndex(where: { $0.hostPeerId == peripheral.identifier.uuidString }) {
                discoveredSessions[sessionIndex] = NearbySession(
                    id: discoveredSessions[sessionIndex].id,
                    hostName: hostName,
                    hostPeerId: peripheral.identifier.uuidString,
                    durationMinutes: duration,
                    betAmount: bet,
                    participantCount: count,
                    signalStrength: RSSI.intValue
                )
            }
        } else {
            discoveredPeripherals.append(peripheral)

            let session = NearbySession(
                id: UUID(),
                hostName: hostName,
                hostPeerId: peripheral.identifier.uuidString,
                durationMinutes: duration,
                betAmount: bet,
                participantCount: count,
                signalStrength: RSSI.intValue
            )
            discoveredSessions.append(session)
            onSessionDiscovered?(session)
            logger.info("Discovered session: host=\(hostName), duration=\(duration)min, bet=\(bet), participants=\(count)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([BluetoothConstants.serviceUUID])
        connectedPeers.append(peripheral.identifier.uuidString)
        logger.info("Connected to peripheral: \(peripheral.identifier.uuidString)")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        logger.error("Failed to connect to peripheral \(peripheral.identifier.uuidString): \(errorMsg)")
        onError?(.connectionFailed(errorMsg))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeers.removeAll { $0 == peripheral.identifier.uuidString }
        connectedPeripheral = nil
        stopHeartbeatTimeoutCheck()

        if let error = error {
            logger.error("Peripheral disconnected with error: \(error.localizedDescription)")
            onError?(.connectionFailed("Disconnected: \(error.localizedDescription)"))
        } else {
            logger.info("Peripheral disconnected: \(peripheral.identifier.uuidString)")
        }

        // Report disconnection
        if let session = currentSession,
           let participant = session.participants.first(where: { $0.peerId == peripheral.identifier.uuidString }) {
            onParticipantLeft?(participant.id)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Service discovery failed: \(error.localizedDescription)")
            onError?(.connectionFailed("Service discovery failed: \(error.localizedDescription)"))
            return
        }

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
        if let error = error {
            logger.error("Characteristic discovery failed: \(error.localizedDescription)")
            onError?(.connectionFailed("Characteristic discovery failed: \(error.localizedDescription)"))
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic) // Initial read
            } else if characteristic.uuid == BluetoothConstants.controlCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == BluetoothConstants.heartbeatCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                startHeartbeatTimeoutCheck()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Failed to read value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            onError?(.messageDeliveryFailed("Read failed: \(error.localizedDescription)"))
            return
        }

        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case BluetoothConstants.sessionCharacteristicUUID:
            do {
                let session = try JSONDecoder().decode(Session.self, from: data)
                currentSession = session
                onSessionReceived?(session)
                logger.debug("Received session info: \(session.participants.count) participants")
            } catch {
                logger.error("Failed to decode session info (\(data.count) bytes): \(error.localizedDescription)")
                onError?(.messageDecodingFailed("session info"))
            }

        case BluetoothConstants.controlCharacteristicUUID:
            do {
                let message = try JSONDecoder().decode(BluetoothMessage.self, from: data)
                handleReceivedControlMessage(message)
            } catch {
                logger.error("Failed to decode control message (\(data.count) bytes): \(error.localizedDescription)")
                onError?(.messageDecodingFailed("control message"))
            }

        case BluetoothConstants.heartbeatCharacteristicUUID:
            lastHeartbeatTime = Date()

        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Failed to write value to characteristic \(characteristic.uuid): \(error.localizedDescription)")
            onError?(.messageDeliveryFailed("Write failed: \(error.localizedDescription)"))
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        isBluetoothEnabled = peripheral.state == .poweredOn
        logger.info("Peripheral manager state updated: \(peripheral.state.rawValue) (poweredOn=\(peripheral.state == .poweredOn))")

        if peripheral.state != .poweredOn && peripheral.state != .unknown {
            onError?(.bluetoothPoweredOff)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == BluetoothConstants.controlCharacteristicUUID,
               let data = request.value {
                do {
                    let message = try JSONDecoder().decode(BluetoothMessage.self, from: data)
                    handleReceivedControlMessage(message)
                    peripheral.respond(to: request, withResult: .success)
                } catch {
                    logger.error("Failed to decode write request (\(data.count) bytes): \(error.localizedDescription)")
                    peripheral.respond(to: request, withResult: .requestNotSupported)
                    onError?(.messageDecodingFailed("write request"))
                }
            } else {
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedPeers.append(central.identifier.uuidString)
        logger.info("Central subscribed to \(characteristic.uuid): \(central.identifier.uuidString)")

        // If session char, send current session
        if characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID,
           let session = currentSession,
           let sessionChar = self.sessionCharacteristic {
            do {
                let data = try JSONEncoder().encode(session)
                peripheralManager.updateValue(data, for: sessionChar, onSubscribedCentrals: [central])
            } catch {
                logger.error("Failed to encode session for new subscriber: \(error.localizedDescription)")
                onError?(.messageEncodingFailed("session for subscriber"))
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID {
            connectedPeers.removeAll { $0 == central.identifier.uuidString }
            logger.info("Central unsubscribed from session: \(central.identifier.uuidString)")
        }
    }

    // Read request for Session Characteristic
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == BluetoothConstants.sessionCharacteristicUUID {
            guard let session = currentSession else {
                logger.warning("Read request received but no current session")
                peripheral.respond(to: request, withResult: .attributeNotFound)
                return
            }

            do {
                let data = try JSONEncoder().encode(session)

                if request.offset > data.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }

                request.value = data.subdata(in: request.offset..<data.count)
                peripheral.respond(to: request, withResult: .success)
            } catch {
                logger.error("Failed to encode session for read request: \(error.localizedDescription)")
                peripheral.respond(to: request, withResult: .attributeNotFound)
                onError?(.messageEncodingFailed("session read request"))
            }
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }
}
