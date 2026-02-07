//
//  WalletManager.swift
//  campy
//
//  Manages user balance and transactions
//

import SwiftUI
import CloudKit

@Observable
@MainActor
class WalletManager {
    private(set) var balance: Int = 0
    private(set) var transactions: [Transaction] = []

    private let userDefaults = UserDefaults.standard
    private let balanceKey = "userBalance"
    private let transactionsKey = "userTransactions"

    weak var cloudKitManager: CloudKitManager?

    init() {
        loadLocalData()
    }

    // MARK: - Balance Operations

    func addCoins(amount: Int, description: String) {
        balance += amount

        let transaction = Transaction(
            userId: currentUserId,
            type: .purchase,
            amount: amount,
            description: description
        )
        transactions.insert(transaction, at: 0)

        saveLocalData()
        syncToCloud()
    }

    func addWinnings(amount: Int) {
        balance += amount

        let transaction = Transaction(
            userId: currentUserId,
            type: .sessionWin,
            amount: amount,
            description: "Won challenge"
        )
        transactions.insert(transaction, at: 0)

        saveLocalData()
        syncToCloud()
    }

    func deductBet(amount: Int) {
        guard balance >= amount else { return }
        balance -= amount

        let transaction = Transaction(
            userId: currentUserId,
            type: .sessionLoss,
            amount: -amount,
            description: "Challenge bet"
        )
        transactions.insert(transaction, at: 0)

        saveLocalData()
        syncToCloud()
    }

    func refund(amount: Int, reason: String) {
        balance += amount

        let transaction = Transaction(
            userId: currentUserId,
            type: .refund,
            amount: amount,
            description: reason
        )
        transactions.insert(transaction, at: 0)

        saveLocalData()
        syncToCloud()
    }

    func hasEnoughBalance(for amount: Int) -> Bool {
        balance >= amount
    }

    // MARK: - Persistence

    private func loadLocalData() {
        balance = userDefaults.integer(forKey: balanceKey)

        if let data = userDefaults.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            transactions = decoded
        }

        // Set initial balance for new users
        if balance == 0 && transactions.isEmpty {
            balance = 100 // Welcome bonus
            let transaction = Transaction(
                userId: currentUserId,
                type: .bonus,
                amount: 100,
                description: "Welcome bonus!"
            )
            transactions = [transaction]
            saveLocalData()
        }
    }

    private func saveLocalData() {
        userDefaults.set(balance, forKey: balanceKey)

        if let encoded = try? JSONEncoder().encode(transactions) {
            userDefaults.set(encoded, forKey: transactionsKey)
        }
    }

    private func syncToCloud() {
        // Sync to CloudKit if available
        cloudKitManager?.syncWalletData(balance: balance, transactions: transactions)
    }

    private var currentUserId: UUID {
        if let idString = userDefaults.string(forKey: "userId"),
           let id = UUID(uuidString: idString) {
            return id
        }
        let newId = UUID()
        userDefaults.set(newId.uuidString, forKey: "userId")
        return newId
    }

    // MARK: - Demo Data (for development)

    func loadDemoData() {
        balance = 3284
        transactions = Transaction.previewTransactions
    }
}
