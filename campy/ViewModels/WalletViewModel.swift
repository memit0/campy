//
//  WalletViewModel.swift
//  campy
//
//  ViewModel for wallet screen
//

import SwiftUI
import StoreKit

@Observable
class WalletViewModel {
    var showAddFunds = false
    var showWithdraw = false
    var isLoading = false
    var error: String?
    var purchaseSuccess = false

    var coinPackages: [CoinPackage] = CoinPackage.defaultPackages
    var selectedPackage: CoinPackage?

    weak var walletManager: WalletManager?
    weak var storeKitManager: StoreKitManager?

    var balance: Int {
        walletManager?.balance ?? 0
    }

    var transactions: [Transaction] {
        walletManager?.transactions ?? []
    }

    // MARK: - Actions

    func openAddFunds() {
        showAddFunds = true
    }

    func openWithdraw() {
        // Disabled for v1
        showWithdraw = true
    }

    func selectPackage(_ package: CoinPackage) {
        selectedPackage = package
    }

    func purchaseSelectedPackage() async {
        guard let package = selectedPackage,
              let storeKitManager = storeKitManager else { return }

        isLoading = true
        error = nil

        do {
            let success = try await storeKitManager.purchase(productId: package.id)
            await MainActor.run {
                isLoading = false
                if success {
                    walletManager?.addCoins(amount: package.coins, description: "Added funds via Apple Pay")
                    purchaseSuccess = true
                    showAddFunds = false
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error.localizedDescription
            }
        }
    }

    func loadProducts() async {
        guard let storeKitManager = storeKitManager else { return }

        let products = await storeKitManager.loadProducts()

        await MainActor.run {
            // Match products to packages
            for (index, package) in coinPackages.enumerated() {
                if let product = products.first(where: { $0.id == package.id }) {
                    coinPackages[index].product = product
                }
            }
        }
    }
}
