//
//  Session.swift
//  campy
//
//  Session model representing a game session
//

import Foundation

enum SessionState: String, Codable {
    case waiting      // Host created session, waiting for players
    case countdown    // All players ready, countdown before start
    case active       // Game in progress
    case ended        // Game ended (someone lost or timer completed)
    case cancelled    // Session was cancelled
}

struct Session: Identifiable, Codable {
    let id: UUID
    let hostId: UUID
    var participants: [SessionParticipant]
    var durationMinutes: Int
    var betAmount: Int
    var state: SessionState
    var startedAt: Date?
    var endedAt: Date?
    var loserId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hostId: UUID,
        participants: [SessionParticipant] = [],
        durationMinutes: Int = 15,
        betAmount: Int = 15,
        state: SessionState = .waiting,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        loserId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hostId = hostId
        self.participants = participants
        self.durationMinutes = durationMinutes
        self.betAmount = betAmount
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.loserId = loserId
        self.createdAt = createdAt
    }

    var totalPot: Int {
        participants.count * betAmount
    }

    var activeParticipants: [SessionParticipant] {
        participants.filter { !$0.hasLost }
    }

    var loser: SessionParticipant? {
        participants.first { $0.hasLost }
    }

    var winners: [SessionParticipant] {
        participants.filter { !$0.hasLost }
    }

    var remainingTime: TimeInterval? {
        guard let startedAt = startedAt, state == .active else { return nil }
        let elapsed = Date().timeIntervalSince(startedAt)
        let total = TimeInterval(durationMinutes * 60)
        return max(0, total - elapsed)
    }

    var isCompleted: Bool {
        state == .ended || state == .cancelled
    }

    mutating func markParticipantAsLost(participantId: UUID) {
        if let index = participants.firstIndex(where: { $0.id == participantId }) {
            participants[index].hasLost = true
            participants[index].lostAt = Date()
            loserId = participantId
            state = .ended
            endedAt = Date()
        }
    }

    mutating func start() {
        state = .active
        startedAt = Date()
    }

    mutating func end() {
        state = .ended
        endedAt = Date()
    }

    static var preview: Session {
        Session(
            hostId: UUID(),
            participants: [
                SessionParticipant(peerId: "host", displayName: "Emma", avatarColorIndex: 0, isHost: true),
                SessionParticipant(peerId: "peer1", displayName: "Sam", avatarColorIndex: 1),
                SessionParticipant(peerId: "peer2", displayName: "Kim", avatarColorIndex: 2)
            ],
            durationMinutes: 15,
            betAmount: 20,
            state: .active,
            startedAt: Date()
        )
    }
}

// MARK: - Nearby Session (for discovery)
struct NearbySession: Identifiable {
    let id: UUID
    let hostName: String
    let hostPeerId: String
    let durationMinutes: Int
    let betAmount: Int
    let participantCount: Int
    var signalStrength: Int // RSSI value

    var formattedBet: String {
        "\(betAmount)b"
    }

    var formattedDuration: String {
        "\(durationMinutes) min"
    }
}
