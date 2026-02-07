//
//  SessionViewModel.swift
//  campy
//
//  ViewModel for session setup and active game
//

import SwiftUI
import Combine

@Observable
class SessionViewModel {
    // Session setup state
    var selectedTimeIndex: Int? = nil
    var selectedBetIndex: Int? = nil
    var pickerMode: PickerMode = .time

    // Session state
    var currentSession: Session?
    var isHost: Bool = false
    var isConnecting: Bool = false
    var error: String?

    // Timer state
    var remainingSeconds: Int = 0
    var isTimerRunning: Bool = false

    private var timerCancellable: AnyCancellable?
    private var watchdogCancellable: AnyCancellable?
    private static let watchdogIntervalSeconds: TimeInterval = 5
    private static let watchdogGraceSeconds: TimeInterval = 10

    // Reference to managers
    weak var bluetoothManager: BluetoothManager?
    weak var gameManager: GameManager?
    weak var walletManager: WalletManager?

    // Computed properties
    var selectedDuration: Int? {
        guard let index = selectedTimeIndex,
              index >= 0 && index < CampyOptions.timeOptions.count else { return nil }
        return CampyOptions.timeOptions[index]
    }

    var selectedBet: Int? {
        guard let index = selectedBetIndex,
              index >= 0 && index < CampyOptions.betOptions.count else { return nil }
        return CampyOptions.betOptions[index]
    }

    var hasSelectedTimeAndBet: Bool {
        selectedTimeIndex != nil && selectedBetIndex != nil
    }

    var formattedTimeRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var canStartSession: Bool {
        guard let walletManager = walletManager,
              let selectedBet = selectedBet,
              hasSelectedTimeAndBet else { return false }
        return walletManager.balance >= selectedBet
    }

    var participants: [SessionParticipant] {
        currentSession?.participants ?? []
    }

    // MARK: - Session Setup

    func startSession() {
        guard hasSelectedTimeAndBet else {
            error = "Please select both time and bet amount."
            return
        }
        guard let duration = selectedDuration, duration > 0 else {
            error = "Invalid time selection."
            return
        }
        guard let bet = selectedBet, bet > 0 else {
            error = "Invalid bet amount."
            return
        }
        guard canStartSession else {
            error = "Insufficient balance for this bet."
            return
        }

        isHost = true
        isConnecting = true

        // Create session
        let hostParticipant = SessionParticipant(
            peerId: bluetoothManager?.localPeerId ?? UUID().uuidString,
            displayName: UserDefaults.standard.string(forKey: "displayName") ?? "Host",
            avatarColorIndex: Int.random(in: 0..<CampyColors.avatarColors.count),
            isHost: true
        )

        let session = Session(
            hostId: hostParticipant.id,
            participants: [hostParticipant],
            durationMinutes: duration,
            betAmount: bet,
            state: .waiting
        )

        currentSession = session

        // Initialize timer with selected duration and start it
        remainingSeconds = duration * 60
        startTimer()

        // Start advertising
        bluetoothManager?.startAdvertising(session: session)
    }

    func joinSession(_ nearbySession: NearbySession) {
        isHost = false
        isConnecting = true
        bluetoothManager?.connectToHost(peerId: nearbySession.hostPeerId)
    }

    func cancelSession() {
        bluetoothManager?.stopAdvertising()
        bluetoothManager?.disconnect()
        currentSession = nil
        isConnecting = false
        isHost = false
    }

    // MARK: - Game Control

    func startGame() {
        guard var session = currentSession else { return }
        session.start()
        currentSession = session
        remainingSeconds = session.durationMinutes * 60
        startTimer()
        startWatchdog()

        // Deduct bet from wallet
        walletManager?.deductBet(amount: session.betAmount)

        // Notify all participants
        bluetoothManager?.broadcastGameStart()
    }

    func reportLoss() {
        guard let session = currentSession,
              let localPeerId = bluetoothManager?.localPeerId else { return }

        // Find local participant
        if let participant = session.participants.first(where: { $0.peerId == localPeerId }) {
            bluetoothManager?.reportLoss(participantId: participant.id)
        }

        stopTimer()
    }

    func endGame(loserId: UUID?) {
        stopTimer()

        guard var session = currentSession else { return }
        if let loserId = loserId {
            session.markParticipantAsLost(participantId: loserId)
        } else {
            session.end()
        }
        currentSession = session

        // Calculate winnings
        if let loserId = loserId {
            let localPeerId = bluetoothManager?.localPeerId
            let localParticipant = session.participants.first { $0.peerId == localPeerId }

            if localParticipant?.id != loserId {
                // We won!
                let winners = session.winners
                let totalPot = session.totalPot
                let winnings = totalPot / winners.count
                walletManager?.addWinnings(amount: winnings)
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        isTimerRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.timerCompleted()
                }
            }
    }

    private func stopTimer() {
        isTimerRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        watchdogCancellable?.cancel()
        watchdogCancellable = nil
    }

    private func timerCompleted() {
        stopTimer()
        // Everyone who stayed wins!
        endGame(loserId: nil)
    }

    private func startWatchdog() {
        watchdogCancellable = Timer.publish(
            every: Self.watchdogIntervalSeconds, on: .main, in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.checkWatchdog()
        }
    }

    private func checkWatchdog() {
        guard isTimerRunning,
              let session = currentSession,
              let startedAt = session.startedAt else { return }

        let elapsed = Date().timeIntervalSince(startedAt)
        let expectedDuration = TimeInterval(session.durationMinutes * 60)

        if elapsed >= expectedDuration + Self.watchdogGraceSeconds {
            timerCompleted()
        }
    }

    // MARK: - Bluetooth Callbacks

    func onParticipantJoined(_ participant: SessionParticipant) {
        currentSession?.participants.append(participant)
    }

    func onParticipantLeft(_ participantId: UUID) {
        currentSession?.markParticipantAsLost(participantId: participantId)
        if currentSession?.state == .active {
            endGame(loserId: participantId)
        }
    }

    func onGameStarted() {
        guard var session = currentSession else { return }
        session.start()
        currentSession = session
        remainingSeconds = session.durationMinutes * 60
        startTimer()
        startWatchdog()

        // Deduct bet
        walletManager?.deductBet(amount: session.betAmount)
    }

    func onSessionReceived(_ session: Session) {
        guard session.durationMinutes > 0,
              session.betAmount > 0,
              CampyOptions.timeOptions.contains(session.durationMinutes),
              CampyOptions.betOptions.contains(session.betAmount) else {
            error = "Invalid session parameters received."
            isConnecting = false
            return
        }
        currentSession = session
        isConnecting = false
    }
}
