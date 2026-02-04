//
//  CloudKitManager.swift
//  campy
//
//  Manages iCloud sync via CloudKit
//

import SwiftUI
import CloudKit

/// Represents the various states of CloudKit initialization
enum CloudKitInitializationState: CustomStringConvertible {
    case notStarted
    case initializing
    case checkingAccountStatus
    case available
    case unavailable(reason: String)
    case failed(error: CloudKitError)

    var description: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .initializing:
            return "Initializing..."
        case .checkingAccountStatus:
            return "Checking Account Status..."
        case .available:
            return "Available"
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

/// Custom error types for CloudKit operations with detailed descriptions
enum CloudKitError: LocalizedError {
    case containerNotFound(identifier: String?)
    case databaseNotAvailable
    case accountNotAvailable(status: CKAccountStatus)
    case accountStatusCheckFailed(underlyingError: Error)
    case networkUnavailable
    case notAuthenticated
    case quotaExceeded
    case serverError(code: Int, description: String)
    case permissionDenied(description: String)
    case recordNotFound(recordName: String)
    case saveFailed(recordType: String, underlyingError: Error)
    case fetchFailed(recordType: String, underlyingError: Error)
    case unknownError(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .containerNotFound(let identifier):
            return "CloudKit container not found. Container identifier: \(identifier ?? "nil"). Verify that the iCloud container is properly configured in your Apple Developer account and matches the entitlements file."
        case .databaseNotAvailable:
            return "CloudKit private database is not available. This may indicate an issue with iCloud configuration or the user is not signed into iCloud."
        case .accountNotAvailable(let status):
            return "iCloud account is not available. Status: \(describeAccountStatus(status)). The user must sign into iCloud in Settings to use cloud sync features."
        case .accountStatusCheckFailed(let underlyingError):
            return "Failed to check iCloud account status. Underlying error: \(underlyingError.localizedDescription). This may be a temporary network issue."
        case .networkUnavailable:
            return "Network is unavailable. CloudKit requires an active internet connection to sync data."
        case .notAuthenticated:
            return "User is not authenticated with iCloud. Please sign into iCloud in device Settings > Apple ID > iCloud."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. The user needs to free up iCloud storage or upgrade their storage plan."
        case .serverError(let code, let description):
            return "CloudKit server error (code: \(code)). Description: \(description). This is typically a temporary issue with Apple's servers."
        case .permissionDenied(let description):
            return "Permission denied: \(description). Check that the app has proper iCloud entitlements and capabilities enabled."
        case .recordNotFound(let recordName):
            return "Record not found: \(recordName). This may be the first sync for this user."
        case .saveFailed(let recordType, let underlyingError):
            return "Failed to save \(recordType) record. Error: \(underlyingError.localizedDescription)"
        case .fetchFailed(let recordType, let underlyingError):
            return "Failed to fetch \(recordType) records. Error: \(underlyingError.localizedDescription)"
        case .unknownError(let underlyingError):
            return "An unknown CloudKit error occurred: \(underlyingError.localizedDescription)"
        }
    }

    private func describeAccountStatus(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud account configured on this device"
        case .restricted:
            return "iCloud access is restricted (possibly by parental controls or MDM)"
        case .couldNotDetermine:
            return "Could not determine account status"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        @unknown default:
            return "Unknown status (code: \(status.rawValue))"
        }
    }
}

@Observable
class CloudKitManager {
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?

    private(set) var isSyncing = false
    private(set) var syncError: Error?
    private(set) var isAvailable = false
    private(set) var isInitialized = false
    private(set) var initializationState: CloudKitInitializationState = .notStarted
    private(set) var lastError: CloudKitError?

    private let userRecordType = "User"
    private let transactionRecordType = "Transaction"

    init() {
        // Defer CloudKit initialization to avoid crashes during app launch
        // Call initialize() when ready to use CloudKit
        logInfo("CloudKitManager instance created. Call initialize() to start CloudKit.")
    }

    // MARK: - Logging Helpers

    private func logInfo(_ message: String) {
        #if DEBUG
        print("☁️ [CloudKit INFO] \(message)")
        #endif
    }

    private func logWarning(_ message: String) {
        #if DEBUG
        print("⚠️ [CloudKit WARNING] \(message)")
        #endif
    }

    private func logError(_ message: String, error: Error? = nil) {
        #if DEBUG
        if let error = error {
            print("❌ [CloudKit ERROR] \(message)")
            print("   └─ Error Type: \(type(of: error))")
            print("   └─ Description: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("   └─ CKError Code: \(ckError.code.rawValue) (\(describeCKErrorCode(ckError.code)))")
                if let retryAfter = ckError.retryAfterSeconds {
                    print("   └─ Retry After: \(retryAfter) seconds")
                }
                if let underlyingError = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("   └─ Underlying Error: \(underlyingError.localizedDescription)")
                }
            }
        } else {
            print("❌ [CloudKit ERROR] \(message)")
        }
        #endif
    }

    private func describeCKErrorCode(_ code: CKError.Code) -> String {
        switch code {
        case .internalError: return "internalError"
        case .partialFailure: return "partialFailure"
        case .networkUnavailable: return "networkUnavailable"
        case .networkFailure: return "networkFailure"
        case .badContainer: return "badContainer"
        case .serviceUnavailable: return "serviceUnavailable"
        case .requestRateLimited: return "requestRateLimited"
        case .missingEntitlement: return "missingEntitlement"
        case .notAuthenticated: return "notAuthenticated"
        case .permissionFailure: return "permissionFailure"
        case .unknownItem: return "unknownItem"
        case .invalidArguments: return "invalidArguments"
        case .serverRecordChanged: return "serverRecordChanged"
        case .serverRejectedRequest: return "serverRejectedRequest"
        case .assetFileNotFound: return "assetFileNotFound"
        case .assetFileModified: return "assetFileModified"
        case .incompatibleVersion: return "incompatibleVersion"
        case .constraintViolation: return "constraintViolation"
        case .operationCancelled: return "operationCancelled"
        case .changeTokenExpired: return "changeTokenExpired"
        case .batchRequestFailed: return "batchRequestFailed"
        case .zoneBusy: return "zoneBusy"
        case .badDatabase: return "badDatabase"
        case .quotaExceeded: return "quotaExceeded"
        case .zoneNotFound: return "zoneNotFound"
        case .limitExceeded: return "limitExceeded"
        case .userDeletedZone: return "userDeletedZone"
        case .tooManyParticipants: return "tooManyParticipants"
        case .alreadyShared: return "alreadyShared"
        case .referenceViolation: return "referenceViolation"
        case .managedAccountRestricted: return "managedAccountRestricted"
        case .participantMayNeedVerification: return "participantMayNeedVerification"
        case .serverResponseLost: return "serverResponseLost"
        case .assetNotAvailable: return "assetNotAvailable"
        case .accountTemporarilyUnavailable: return "accountTemporarilyUnavailable"
        @unknown default: return "unknown(\(code.rawValue))"
        }
    }

    // MARK: - Initialization

    func initialize() {
        guard !isInitialized else {
            logWarning("initialize() called but CloudKit is already initialized. State: \(initializationState)")
            return
        }

        initializationState = .initializing
        logInfo("Starting CloudKit initialization...")
        logInfo("Bundle Identifier: \(Bundle.main.bundleIdentifier ?? "nil")")

        // Check entitlements info
        if let entitlementsPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            logInfo("Found embedded.mobileprovision at: \(entitlementsPath)")
        } else {
            logWarning("No embedded.mobileprovision found - this is normal for simulator builds")
        }

        // Use default container to match entitlements (which use CFBundleIdentifier variable)
        logInfo("Attempting to get default CKContainer...")
        container = CKContainer.default()

        guard let container = container else {
            let error = CloudKitError.containerNotFound(identifier: nil)
            logError("Failed to get default container", error: error)
            lastError = error
            initializationState = .failed(error: error)
            return
        }

        let containerIdentifier = container.containerIdentifier ?? "unknown"
        logInfo("Successfully obtained CKContainer")
        logInfo("Container Identifier: \(containerIdentifier)")

        // Verify container identifier matches expected format
        if containerIdentifier == "unknown" || containerIdentifier.isEmpty {
            logWarning("Container identifier is empty or unknown. This may indicate a configuration issue.")
        } else if !containerIdentifier.starts(with: "iCloud.") {
            logWarning("Container identifier '\(containerIdentifier)' does not start with 'iCloud.' - verify entitlements configuration")
        }

        logInfo("Obtaining private database reference...")
        privateDatabase = container.privateCloudDatabase

        guard privateDatabase != nil else {
            let error = CloudKitError.databaseNotAvailable
            logError("Failed to get private database reference", error: error)
            lastError = error
            initializationState = .failed(error: error)
            return
        }

        logInfo("Successfully obtained private database reference")
        isInitialized = true

        logInfo("CloudKit basic initialization complete. Checking account status...")
        checkAccountStatus()
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        guard let container = container else {
            logError("checkAccountStatus() called but container is nil")
            isAvailable = false
            initializationState = .failed(error: .containerNotFound(identifier: nil))
            return
        }

        initializationState = .checkingAccountStatus
        logInfo("Checking iCloud account status...")

        Task { @MainActor in
            do {
                let status = try await container.accountStatus()
                logInfo("Account status received: \(describeAccountStatus(status))")

                switch status {
                case .available:
                    self.isAvailable = true
                    self.initializationState = .available
                    logInfo("✅ CloudKit is fully available and ready to use")

                case .noAccount:
                    self.isAvailable = false
                    let error = CloudKitError.accountNotAvailable(status: status)
                    self.lastError = error
                    self.initializationState = .unavailable(reason: "No iCloud account")
                    logWarning("No iCloud account is configured on this device")
                    logWarning("User needs to sign into iCloud in Settings > Apple ID > iCloud")

                case .restricted:
                    self.isAvailable = false
                    let error = CloudKitError.accountNotAvailable(status: status)
                    self.lastError = error
                    self.initializationState = .unavailable(reason: "Account restricted")
                    logWarning("iCloud account is restricted (parental controls or MDM)")

                case .couldNotDetermine:
                    self.isAvailable = false
                    let error = CloudKitError.accountNotAvailable(status: status)
                    self.lastError = error
                    self.initializationState = .unavailable(reason: "Status undetermined")
                    logWarning("Could not determine iCloud account status - this may be temporary")

                case .temporarilyUnavailable:
                    self.isAvailable = false
                    let error = CloudKitError.accountNotAvailable(status: status)
                    self.lastError = error
                    self.initializationState = .unavailable(reason: "Temporarily unavailable")
                    logWarning("iCloud is temporarily unavailable - will retry later")

                @unknown default:
                    self.isAvailable = false
                    let error = CloudKitError.accountNotAvailable(status: status)
                    self.lastError = error
                    self.initializationState = .unavailable(reason: "Unknown status")
                    logWarning("Unknown iCloud account status: \(status.rawValue)")
                }
            } catch {
                logError("Failed to check iCloud account status", error: error)
                self.isAvailable = false

                let cloudKitError = mapToCKError(error)
                self.lastError = cloudKitError
                self.initializationState = .failed(error: cloudKitError)
            }
        }
    }

    private func describeAccountStatus(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private func mapToCKError(_ error: Error) -> CloudKitError {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return .networkUnavailable
            case .notAuthenticated:
                return .notAuthenticated
            case .quotaExceeded:
                return .quotaExceeded
            case .permissionFailure, .missingEntitlement:
                return .permissionDenied(description: ckError.localizedDescription)
            case .badContainer:
                return .containerNotFound(identifier: nil)
            case .serviceUnavailable, .serverResponseLost:
                return .serverError(code: ckError.code.rawValue, description: ckError.localizedDescription)
            default:
                return .unknownError(underlyingError: error)
            }
        }
        return .accountStatusCheckFailed(underlyingError: error)
    }

    // MARK: - Sync Operations

    func syncWalletData(balance: Int, transactions: [Transaction]) {
        guard isAvailable else {
            logWarning("syncWalletData() skipped - CloudKit is not available. State: \(initializationState)")
            return
        }
        guard privateDatabase != nil else {
            logError("syncWalletData() failed - private database is nil")
            return
        }

        logInfo("Starting wallet data sync - Balance: \(balance), Transactions: \(transactions.count)")
        isSyncing = true

        Task {
            await syncUserBalance(balance)
            await syncTransactions(transactions)

            await MainActor.run {
                self.isSyncing = false
                logInfo("Wallet data sync completed")
            }
        }
    }

    private func syncUserBalance(_ balance: Int) async {
        guard let privateDatabase = privateDatabase else {
            logError("syncUserBalance() failed - private database is nil")
            return
        }

        logInfo("Syncing user balance: \(balance)")

        do {
            let userId = getUserId()
            let recordId = CKRecord.ID(recordName: userId)
            logInfo("User record ID: \(userId)")

            // Try to fetch existing record
            let existingRecord: CKRecord
            do {
                logInfo("Attempting to fetch existing user record...")
                existingRecord = try await privateDatabase.record(for: recordId)
                logInfo("Found existing user record")
            } catch {
                logInfo("No existing user record found, creating new one")
                if let ckError = error as? CKError {
                    logInfo("CKError code: \(describeCKErrorCode(ckError.code))")
                }
                existingRecord = CKRecord(recordType: userRecordType, recordID: recordId)
            }

            existingRecord["balance"] = balance
            existingRecord["updatedAt"] = Date()

            logInfo("Saving user record with balance: \(balance)")
            _ = try await privateDatabase.save(existingRecord)
            logInfo("✅ Successfully saved user balance")
        } catch {
            logError("Failed to sync user balance", error: error)
            await MainActor.run {
                self.syncError = error
                self.lastError = .saveFailed(recordType: userRecordType, underlyingError: error)
            }
        }
    }

    private func syncTransactions(_ transactions: [Transaction]) async {
        guard let privateDatabase = privateDatabase else {
            logError("syncTransactions() failed - private database is nil")
            return
        }

        // Only sync the most recent transactions
        let recentTransactions = Array(transactions.prefix(50))
        logInfo("Syncing \(recentTransactions.count) transactions (of \(transactions.count) total)")

        var successCount = 0
        var failureCount = 0
        var skippedCount = 0

        for (index, transaction) in recentTransactions.enumerated() {
            do {
                let recordId = CKRecord.ID(recordName: transaction.id.uuidString)
                let record = CKRecord(recordType: transactionRecordType, recordID: recordId)

                record["type"] = transaction.type.rawValue
                record["amount"] = transaction.amount
                record["description"] = transaction.description
                record["createdAt"] = transaction.createdAt

                _ = try await privateDatabase.save(record)
                successCount += 1

                if (index + 1) % 10 == 0 {
                    logInfo("Progress: \(index + 1)/\(recentTransactions.count) transactions synced")
                }
            } catch {
                if let ckError = error as? CKError {
                    if ckError.code == .serverRecordChanged {
                        // Record already exists and was modified - skip silently
                        skippedCount += 1
                        continue
                    }
                    logError("Failed to sync transaction \(transaction.id.uuidString)", error: error)
                } else {
                    logError("Failed to sync transaction \(transaction.id.uuidString)", error: error)
                }
                failureCount += 1
            }
        }

        logInfo("Transaction sync complete - Success: \(successCount), Skipped: \(skippedCount), Failed: \(failureCount)")
    }

    // MARK: - Fetch Operations

    func fetchUserData() async -> (balance: Int, transactions: [Transaction])? {
        guard isAvailable else {
            logWarning("fetchUserData() skipped - CloudKit is not available. State: \(initializationState)")
            return nil
        }
        guard let privateDatabase = privateDatabase else {
            logError("fetchUserData() failed - private database is nil")
            return nil
        }

        logInfo("Fetching user data from CloudKit...")

        do {
            let userId = getUserId()
            let recordId = CKRecord.ID(recordName: userId)
            logInfo("Fetching record for user: \(userId)")

            let userRecord = try await privateDatabase.record(for: recordId)
            let balance = userRecord["balance"] as? Int ?? 0
            logInfo("Fetched user balance: \(balance)")

            // Fetch transactions
            logInfo("Fetching transactions...")
            let query = CKQuery(
                recordType: transactionRecordType,
                predicate: NSPredicate(value: true)
            )
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let (matchResults, _) = try await privateDatabase.records(matching: query, resultsLimit: 50)
            logInfo("Received \(matchResults.count) transaction records")

            var transactions: [Transaction] = []
            var parseFailures = 0

            for (recordId, result) in matchResults {
                if case .success(let record) = result {
                    if let transaction = transactionFromRecord(record) {
                        transactions.append(transaction)
                    } else {
                        parseFailures += 1
                        logWarning("Failed to parse transaction record: \(recordId.recordName)")
                    }
                } else if case .failure(let error) = result {
                    logError("Failed to fetch transaction record: \(recordId.recordName)", error: error)
                }
            }

            logInfo("✅ Successfully fetched \(transactions.count) transactions (parse failures: \(parseFailures))")
            return (balance, transactions)
        } catch {
            logError("Failed to fetch user data", error: error)
            await MainActor.run {
                self.lastError = .fetchFailed(recordType: userRecordType, underlyingError: error)
            }
            return nil
        }
    }

    private func transactionFromRecord(_ record: CKRecord) -> Transaction? {
        guard let typeString = record["type"] as? String,
              let type = TransactionType(rawValue: typeString),
              let amount = record["amount"] as? Int,
              let description = record["description"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            logWarning("Transaction record missing required fields: type=\(record["type"] ?? "nil"), amount=\(record["amount"] ?? "nil"), description=\(record["description"] ?? "nil"), createdAt=\(record["createdAt"] ?? "nil")")
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
