//
//  SessionViewModel.swift
//  campy
//
//  ViewModel for session setup and active game
//

import SwiftUI
import Combine

@Observable
@MainActor
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

    // Reference to managers
    weak var bluetoothManager: BluetoothManager?
    weak var gameManager: GameManager?
    weak var walletManager: WalletManager?

    // Computed properties
    var selectedDuration: Int? {
        guard let index = selectedTimeIndex else { return nil }
        return CampyOptions.timeOptions[index]
    }

    var selectedBet: Int? {
        guard let index = selectedBetIndex else { return nil }
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
        guard canStartSession,
              let duration = selectedDuration,
              let bet = selectedBet else {
            error = "Insufficient balance"
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

        // Start advertising — timer will start when the game begins (not during session setup)
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

        // Notify all participants with the session (includes startedAt timestamp)
        bluetoothManager?.broadcastGameStart(session: session)

        beginPlaying(session: session)
    }

    /// Start playing using the session's startedAt as the authoritative time anchor.
    private func beginPlaying(session: Session) {
        // Calculate remaining seconds from the authoritative startedAt timestamp
        if let remaining = session.remainingTime {
            remainingSeconds = Int(remaining.rounded(.up))
        } else {
            remainingSeconds = session.durationMinutes * 60
        }
        startTimer(anchoredTo: session)

        // Deduct bet from wallet
        walletManager?.deductBet(amount: session.betAmount)
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

    /// Anchored session used to periodically correct timer drift.
    private var anchoredSession: Session?

    private func startTimer(anchoredTo session: Session) {
        anchoredSession = session
        isTimerRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Recalculate from the authoritative startedAt to correct drift
                if let remaining = self.anchoredSession?.remainingTime {
                    self.remainingSeconds = Int(remaining.rounded(.up))
                } else if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                }

                if self.remainingSeconds <= 0 {
                    self.remainingSeconds = 0
                    self.timerCompleted()
                }
            }
    }

    private func stopTimer() {
        isTimerRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        anchoredSession = nil
    }

    private func timerCompleted() {
        stopTimer()
        // Everyone who stayed wins!
        endGame(loserId: nil)
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

    func onGameStarted(with receivedSession: Session?) {
        // Use the host's session (with authoritative startedAt) if available
        if let receivedSession = receivedSession {
            currentSession = receivedSession
            beginPlaying(session: receivedSession)
        } else {
            // Fallback: no session in message, start locally
            guard var session = currentSession else { return }
            session.start()
            currentSession = session
            beginPlaying(session: session)
        }
    }

    func onSessionReceived(_ session: Session) {
        currentSession = session
        isConnecting = false
    }
}
