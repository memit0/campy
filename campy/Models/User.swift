//
//  User.swift
//  campy
//
//  User model representing a player in the app
//

import Foundation
import SwiftUI

struct User: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var avatarColorIndex: Int
    var balance: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String = "",
        avatarColorIndex: Int = 0,
        balance: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarColorIndex = avatarColorIndex
        self.balance = balance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var avatarColor: Color {
        let colors = CampyColors.avatarColors
        return colors[avatarColorIndex % colors.count]
    }

    var initials: String {
        let names = displayName.split(separator: " ")
        if names.isEmpty {
            return "?"
        }
        if names.count == 1 {
            return String(names[0].prefix(1)).uppercased()
        }
        return "\(names[0].prefix(1))\(names[1].prefix(1))".uppercased()
    }

    static var preview: User {
        User(
            displayName: "Test User",
            avatarColorIndex: 0,
            balance: 3284
        )
    }
}

// MARK: - Session Participant
struct SessionParticipant: Identifiable, Codable, Equatable {
    let id: UUID
    let peerId: String
    var displayName: String
    var avatarColorIndex: Int
    var isHost: Bool
    var hasLost: Bool
    var lostAt: Date?

    init(
        id: UUID = UUID(),
        peerId: String,
        displayName: String,
        avatarColorIndex: Int,
        isHost: Bool = false,
        hasLost: Bool = false,
        lostAt: Date? = nil
    ) {
        self.id = id
        self.peerId = peerId
        self.displayName = displayName
        self.avatarColorIndex = avatarColorIndex
        self.isHost = isHost
        self.hasLost = hasLost
        self.lostAt = lostAt
    }

    var avatarColor: Color {
        let colors = CampyColors.avatarColors
        return colors[avatarColorIndex % colors.count]
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }
}
