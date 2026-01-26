//
//  CoinPackage.swift
//  campy
//
//  Coin package model for in-app purchases
//

import Foundation
import StoreKit

struct CoinPackage: Identifiable {
    let id: String  // Product ID
    let coins: Int
    let price: String
    var product: Product?

    init(id: String, coins: Int, price: String, product: Product? = nil) {
        self.id = id
        self.coins = coins
        self.price = price
        self.product = product
    }

    var displayPrice: String {
        product?.displayPrice ?? price
    }

    var formattedCoins: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: coins)) ?? "\(coins)"
    }

    static var defaultPackages: [CoinPackage] {
        CampyCoinPackages.packages.map { package in
            CoinPackage(
                id: package.productId,
                coins: package.coins,
                price: package.price
            )
        }
    }
}

// MARK: - StoreKit Product Extension
extension Product {
    var coinAmount: Int? {
        // Extract coin amount from product ID
        // Format: com.campy.coins.100
        let components = id.split(separator: ".")
        if let lastComponent = components.last,
           let amount = Int(lastComponent) {
            return amount
        }
        return nil
    }
}
