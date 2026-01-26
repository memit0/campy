//
//  Transaction.swift
//  campy
//
//  Transaction model for wallet history
//

import Foundation

enum TransactionType: String, Codable {
    case purchase       // Bought coins via IAP
    case sessionWin     // Won a session
    case sessionLoss    // Lost a session
    case refund         // Refund from cancelled session
    case bonus          // Promotional bonus
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Int  // Positive for gains, negative for losses
    let description: String
    let sessionId: UUID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        type: TransactionType,
        amount: Int,
        description: String,
        sessionId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.amount = amount
        self.description = description
        self.sessionId = sessionId
        self.createdAt = createdAt
    }

    var isPositive: Bool {
        amount > 0
    }

    var formattedAmount: String {
        if amount > 0 {
            return "+\(amount)"
        }
        return "\(amount)"
    }

    var displayDescription: String {
        switch type {
        case .purchase:
            return "Added funds via Apple Pay"
        case .sessionWin:
            return "Won challenge"
        case .sessionLoss:
            return "Lost challenge"
        case .refund:
            return "Session refund"
        case .bonus:
            return description
        }
    }

    static var previewTransactions: [Transaction] {
        let userId = UUID()
        return [
            Transaction(userId: userId, type: .purchase, amount: 1000, description: "Added funds via Apple Pay"),
            Transaction(userId: userId, type: .sessionWin, amount: 60, description: "Won challenge"),
            Transaction(userId: userId, type: .sessionLoss, amount: -20, description: "Lost challenge"),
            Transaction(userId: userId, type: .purchase, amount: 1234, description: "Added funds via Apple Pay"),
        ]
    }
}

// MARK: - Transaction Formatting
extension Transaction {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
