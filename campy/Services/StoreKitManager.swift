//
//  StoreKitManager.swift
//  campy
//
//  Manages in-app purchases via StoreKit 2
//

import SwiftUI
import StoreKit

@Observable
class StoreKitManager {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIds: Set<String> = []
    private(set) var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async -> [Product] {
        isLoading = true

        let productIds = CampyCoinPackages.packages.map { $0.productId }

        do {
            let loadedProducts = try await Product.products(for: Set(productIds))
            await MainActor.run {
                self.products = loadedProducts.sorted { $0.price < $1.price }
                self.isLoading = false
            }
            return loadedProducts
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Failed to load products: \(error)")
            return []
        }
    }

    // MARK: - Purchase

    func purchase(productId: String) async throws -> Bool {
        guard let product = products.first(where: { $0.id == productId }) else {
            // Try to load products first
            let loaded = await loadProducts()
            guard let product = loaded.first(where: { $0.id == productId }) else {
                throw StoreError.productNotFound
            }
            return try await performPurchase(product)
        }
        return try await performPurchase(product)
    }

    private func performPurchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await MainActor.run {
                purchasedProductIds.insert(product.id)
            }
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await MainActor.run {
                        self.purchasedProductIds.insert(transaction.productID)
                    }
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        // For consumable purchases (coins), there's nothing to restore
        // They're consumed immediately upon purchase
    }
}

// MARK: - Store Errors
enum StoreError: LocalizedError {
    case productNotFound
    case verificationFailed
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "The requested product was not found."
        case .verificationFailed:
            return "The purchase could not be verified."
        case .purchaseFailed:
            return "The purchase failed. Please try again."
        }
    }
}
