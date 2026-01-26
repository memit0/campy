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
        state = .playing
        remainingSeconds = session.durationMinutes * 60

        // Deduct bet
        walletManager?.deductBet(amount: session.betAmount)

        // Start app lifecycle monitoring
        appLifecycleManager?.startMonitoring()

        // Broadcast game start
        bluetoothManager?.broadcastGameStart()

        // Start timer
        startTimer()
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

    private func startTimer() {
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
        timerCancellable?.cancel()
        timerCancellable = nil
        countdownCancellable?.cancel()
        countdownCancellable = nil
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

        bluetoothManager?.onGameStarted = { [weak self] in
            self?.startGame()
        }

        bluetoothManager?.onGameEnded = { [weak self] loserId in
            self?.endGame(loserId: loserId, isLocalLoss: false)
        }

        bluetoothManager?.onSessionReceived = { [weak self] session in
            self?.currentSession = session
        }
    }
}
