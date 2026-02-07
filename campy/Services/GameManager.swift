//
//  GameManager.swift
//  campy
//
//  Manages game state and logic
//

import SwiftUI
import Combine

enum GameState: Equatable {
    case idle
    case waiting      // Waiting for players to join
    case countdown    // Pre-game countdown
    case playing      // Game in progress
    case ended(winner: Bool)  // Game ended
}

@Observable
@MainActor
class GameManager {
    // State
    private(set) var state: GameState = .idle
    private(set) var currentSession: Session?
    private(set) var remainingSeconds: Int = 0

    // Managers
    weak var bluetoothManager: BluetoothManager?
    weak var walletManager: WalletManager?
    weak var appLifecycleManager: AppLifecycleManager?

    private var timerCancellable: AnyCancellable?
    private var countdownCancellable: AnyCancellable?

    // MARK: - Session Management

    func createSession(duration: Int, betAmount: Int) -> Session? {
        guard let peerId = bluetoothManager?.localPeerId else { return nil }
        guard walletManager?.hasEnoughBalance(for: betAmount) == true else { return nil }

        let hostParticipant = SessionParticipant(
            peerId: peerId,
            displayName: getLocalDisplayName(),
            avatarColorIndex: getLocalAvatarColorIndex(),
            isHost: true
        )

        let session = Session(
            hostId: hostParticipant.id,
            participants: [hostParticipant],
            durationMinutes: duration,
            betAmount: betAmount,
            state: .waiting
        )

        currentSession = session
        state = .waiting

        // Start advertising
        bluetoothManager?.startAdvertising(session: session)

        return session
    }

    func joinSession(_ session: Session, as participant: SessionParticipant) {
        var updatedSession = session
        updatedSession.participants.append(participant)
        currentSession = updatedSession
        state = .waiting
    }

    func leaveSession() {
        bluetoothManager?.stopAdvertising()
        bluetoothManager?.disconnect()
        currentSession = nil
        state = .idle
        stopTimer()
    }

    // MARK: - Game Control

    func startCountdown() {
        state = .countdown
        remainingSeconds = 3

        countdownCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.countdownCancellable?.cancel()
                    self.startGame()
                }
            }
    }

    func startGame() {
        guard var session = currentSession else { return }
        session.start()
        currentSession = session

        // Broadcast game start with session (includes startedAt timestamp)
        // This must happen before starting the local timer so peers receive
        // the authoritative start time as early as possible.
        bluetoothManager?.broadcastGameStart(session: session)

        beginPlaying(session: session)
    }

    /// Start playing using the given session's startedAt as the authoritative time anchor.
    /// Called by both the host (after startGame) and joining peers (after receiving gameStart).
    private func beginPlaying(session: Session) {
        state = .playing

        // Calculate remaining seconds from the authoritative startedAt timestamp
        // to stay synchronized across devices regardless of message delivery latency.
        if let remaining = session.remainingTime {
            remainingSeconds = Int(remaining.rounded(.up))
        } else {
            remainingSeconds = session.durationMinutes * 60
        }

        // Deduct bet
        walletManager?.deductBet(amount: session.betAmount)

        // Start app lifecycle monitoring
        appLifecycleManager?.startMonitoring()

        // Start timer
        startTimer(anchoredTo: session)
    }

    func reportLoss() {
        guard let session = currentSession,
              let peerId = bluetoothManager?.localPeerId,
              let participant = session.participants.first(where: { $0.peerId == peerId }) else { return }

        bluetoothManager?.reportLoss(participantId: participant.id)
        endGame(loserId: participant.id, isLocalLoss: true)
    }

    func handleParticipantLoss(participantId: UUID) {
        endGame(loserId: participantId, isLocalLoss: false)
    }

    private func endGame(loserId: UUID?, isLocalLoss: Bool) {
        stopTimer()
        appLifecycleManager?.stopMonitoring()

        guard var session = currentSession else { return }

        if let loserId = loserId {
            session.markParticipantAsLost(participantId: loserId)

            // Determine if we won
            let localPeerId = bluetoothManager?.localPeerId
            let localParticipant = session.participants.first { $0.peerId == localPeerId }
            let didWin = localParticipant?.id != loserId

            if didWin {
                // Calculate and add winnings
                let winners = session.winners
                let totalPot = session.totalPot
                let winnings = totalPot / max(winners.count, 1)
                walletManager?.addWinnings(amount: winnings)
            }

            state = .ended(winner: didWin)
        } else {
            // Timer completed - everyone who stayed wins
            session.end()
            walletManager?.addWinnings(amount: session.betAmount) // Get bet back + share of losers
            state = .ended(winner: true)
        }

        currentSession = session
    }

    // MARK: - Timer

    /// Anchored session used to periodically correct timer drift.
    private var anchoredSession: Session?

    private func startTimer(anchoredTo session: Session) {
        anchoredSession = session
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Recalculate from the authoritative startedAt to correct any drift
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
        timerCancellable?.cancel()
        timerCancellable = nil
        countdownCancellable?.cancel()
        countdownCancellable = nil
        anchoredSession = nil
    }

    private func timerCompleted() {
        stopTimer()
        endGame(loserId: nil, isLocalLoss: false)
    }

    // MARK: - Helpers

    var formattedTimeRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var participants: [SessionParticipant] {
        currentSession?.participants ?? []
    }

    var betAmount: Int {
        currentSession?.betAmount ?? 0
    }

    private func getLocalDisplayName() -> String {
        UserDefaults.standard.string(forKey: "displayName") ?? "Player"
    }

    private func getLocalAvatarColorIndex() -> Int {
        UserDefaults.standard.integer(forKey: "avatarColorIndex")
    }

    // MARK: - Bluetooth Callbacks

    func setupBluetoothCallbacks() {
        bluetoothManager?.onParticipantJoined = { [weak self] participant in
            self?.currentSession?.participants.append(participant)
        }

        bluetoothManager?.onParticipantLeft = { [weak self] participantId in
            if self?.state == .playing {
                self?.handleParticipantLoss(participantId: participantId)
            }
        }

        bluetoothManager?.onGameStarted = { [weak self] session in
            guard let self = self else { return }
            if let session = session {
                // Joining peer: use the host's session with authoritative startedAt
                self.currentSession = session
                self.beginPlaying(session: session)
            } else {
                self.startGame()
            }
        }

        bluetoothManager?.onGameEnded = { [weak self] loserId in
            self?.endGame(loserId: loserId, isLocalLoss: false)
        }

        bluetoothManager?.onSessionReceived = { [weak self] session in
            self?.currentSession = session
        }
    }
}
