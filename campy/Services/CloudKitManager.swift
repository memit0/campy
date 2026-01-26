//
//  CloudKitManager.swift
//  campy
//
//  Manages iCloud sync via CloudKit
//

import SwiftUI
import CloudKit

@Observable
class CloudKitManager {
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?

    private(set) var isSyncing = false
    private(set) var syncError: Error?
    private(set) var isAvailable = false
    private(set) var isInitialized = false

    private let userRecordType = "User"
    private let transactionRecordType = "Transaction"

    init() {
        // Defer CloudKit initialization to avoid crashes during app launch
        // Call initialize() when ready to use CloudKit
    }

    // MARK: - Initialization

    func initialize() {
        guard !isInitialized else { return }

        #if DEBUG
        print("🔍 CloudKitManager: Starting initialization")
        #endif

        // Use default container to match entitlements (which use CFBundleIdentifier variable)
        container = CKContainer.default()

        #if DEBUG
        print("🔍 CloudKitManager: Container = \(container?.containerIdentifier ?? "nil")")
        #endif

        privateDatabase = container?.privateCloudDatabase
        isInitialized = true

        #if DEBUG
        print("🔍 CloudKitManager: Initialization complete")
        #endif

        checkAccountStatus()
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        guard let container = container else {
            isAvailable = false
            return
        }

        Task { @MainActor in
            do {
                let status = try await container.accountStatus()
                self.isAvailable = (status == .available)
            } catch {
                print("CloudKit account error: \(error)")
                self.isAvailable = false
            }
        }
    }

    // MARK: - Sync Operations

    func syncWalletData(balance: Int, transactions: [Transaction]) {
        guard isAvailable, privateDatabase != nil else { return }

        Task {
            await syncUserBalance(balance)
            await syncTransactions(transactions)
        }
    }

    private func syncUserBalance(_ balance: Int) async {
        guard let privateDatabase = privateDatabase else { return }

        do {
            let userId = getUserId()
            let recordId = CKRecord.ID(recordName: userId)

            // Try to fetch existing record
            let existingRecord: CKRecord
            do {
                existingRecord = try await privateDatabase.record(for: recordId)
            } catch {
                // Create new record if not found
                existingRecord = CKRecord(recordType: userRecordType, recordID: recordId)
            }

            existingRecord["balance"] = balance
            existingRecord["updatedAt"] = Date()

            _ = try await privateDatabase.save(existingRecord)
        } catch {
            print("Failed to sync balance: \(error)")
        }
    }

    private func syncTransactions(_ transactions: [Transaction]) async {
        guard let privateDatabase = privateDatabase else { return }

        // Only sync the most recent transactions
        let recentTransactions = Array(transactions.prefix(50))

        for transaction in recentTransactions {
            do {
                let recordId = CKRecord.ID(recordName: transaction.id.uuidString)
                let record = CKRecord(recordType: transactionRecordType, recordID: recordId)

                record["type"] = transaction.type.rawValue
                record["amount"] = transaction.amount
                record["description"] = transaction.description
                record["createdAt"] = transaction.createdAt

                _ = try await privateDatabase.save(record)
            } catch {
                // Ignore duplicate record errors
                if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                    continue
                }
                print("Failed to sync transaction: \(error)")
            }
        }
    }

    // MARK: - Fetch Operations

    func fetchUserData() async -> (balance: Int, transactions: [Transaction])? {
        guard isAvailable, let privateDatabase = privateDatabase else { return nil }

        do {
            let userId = getUserId()
            let recordId = CKRecord.ID(recordName: userId)
            let userRecord = try await privateDatabase.record(for: recordId)

            let balance = userRecord["balance"] as? Int ?? 0

            // Fetch transactions
            let query = CKQuery(
                recordType: transactionRecordType,
                predicate: NSPredicate(value: true)
            )
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let (matchResults, _) = try await privateDatabase.records(matching: query, resultsLimit: 50)

            var transactions: [Transaction] = []
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    if let transaction = transactionFromRecord(record) {
                        transactions.append(transaction)
                    }
                }
            }

            return (balance, transactions)
        } catch {
            print("Failed to fetch user data: \(error)")
            return nil
        }
    }

    private func transactionFromRecord(_ record: CKRecord) -> Transaction? {
        guard let typeString = record["type"] as? String,
              let type = TransactionType(rawValue: typeString),
              let amount = record["amount"] as? Int,
              let description = record["description"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        return Transaction(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            userId: UUID(uuidString: getUserId()) ?? UUID(),
            type: type,
            amount: amount,
            description: description,
            createdAt: createdAt
        )
    }

    // MARK: - Helpers

    private func getUserId() -> String {
        if let id = UserDefaults.standard.string(forKey: "userId") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "userId")
        return newId
    }
}
