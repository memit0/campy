//
//  WalletView.swift
//  campy
//
//  Wallet screen with balance and transaction history
//

import SwiftUI

struct WalletView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(StoreKitManager.self) private var storeKitManager

    @State private var viewModel = WalletViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            CampyColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, CampySpacing.lg)
                    .padding(.top, CampySpacing.md)

                ScrollView {
                    VStack(spacing: 0) {
                        // Balance section
                        balanceSection
                            .padding(.top, CampySpacing.xl)

                        // Action buttons
                        actionButtons
                            .padding(.top, CampySpacing.lg)
                            .padding(.horizontal, CampySpacing.lg)

                        // Transaction history
                        transactionSection
                            .padding(.top, CampySpacing.xl)
                            .padding(.bottom, CampySpacing.xl)
                    }
                }
            }
        }
        .onAppear {
            viewModel.walletManager = walletManager
            viewModel.storeKitManager = storeKitManager
        }
        .sheet(isPresented: $viewModel.showAddFunds) {
            AddFundsSheet(viewModel: viewModel)
        }
        .alert("Withdrawals Coming Soon", isPresented: $viewModel.showWithdraw) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Withdrawals will be available in a future update.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var headerView: some View {
        HStack {
            BalanceView(balance: walletManager.balance, style: .compact)
            Spacer()
            Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundColor(CampyColors.textSecondary)
            }
        }
    }

    private var balanceSection: some View {
        VStack(spacing: CampySpacing.md) {
            // Coin mascot
            CoinMascotView(size: 140)

            // Balance display
            BalanceView(balance: walletManager.balance, style: .expanded)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: CampySpacing.md) {
            PillButton(secondary: "Add Funds") {
                viewModel.openAddFunds()
            }

            PillButton(secondary: "Withdraw") {
                viewModel.openWithdraw()
            }
        }
    }

    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: CampySpacing.md) {
            Text("Transaction History")
                .font(CampyFonts.subheader())
                .foregroundColor(CampyColors.textPrimary)
                .padding(.horizontal, CampySpacing.lg)

            if walletManager.transactions.isEmpty {
                emptyTransactionsView
            } else {
                transactionListView
            }
        }
    }

    private var emptyTransactionsView: some View {
        VStack(spacing: CampySpacing.md) {
            Text("No transactions yet")
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CampySpacing.xl)
    }

    private var transactionListView: some View {
        LazyVStack(spacing: CampySpacing.sm) {
            ForEach(walletManager.transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
        .padding(.horizontal, CampySpacing.lg)
    }
}

// MARK: - Add Funds Sheet
struct AddFundsSheet: View {
    @Bindable var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            SheetHandle()
                .padding(.top, CampySpacing.md)

            // Content
            VStack(spacing: CampySpacing.lg) {
                // Coin packages grid
                LazyVGrid(columns: columns, spacing: CampySpacing.md) {
                    ForEach(viewModel.coinPackages) { package in
                        CoinPackageCard(
                            package: package,
                            isSelected: viewModel.selectedPackage?.id == package.id
                        ) {
                            viewModel.selectPackage(package)
                        }
                    }
                }
                .padding(.horizontal, CampySpacing.lg)

                Spacer()

                // Apple Pay button
                if viewModel.selectedPackage != nil {
                    ApplePayButton {
                        Task {
                            await viewModel.purchaseSelectedPackage()
                        }
                    }
                    .frame(height: 50)
                    .padding(.horizontal, CampySpacing.lg)
                }
            }
            .padding(.top, CampySpacing.lg)
            .padding(.bottom, CampySpacing.xl)
        }
        .background(CampyColors.sheetBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task {
            await viewModel.loadProducts()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

// MARK: - Coin Package Card
struct CoinPackageCard: View {
    let package: CoinPackage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: CampySpacing.sm) {
                // Coin icon
                CoinMascotView(size: 80)

                // Coin amount
                Text("\(package.coins)")
                    .font(CampyFonts.body())
                    .foregroundColor(CampyColors.textPrimary)

                // Price
                Text(package.displayPrice)
                    .font(CampyFonts.caption())
                    .foregroundColor(CampyColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CampySpacing.md)
            .background(CampyColors.cardBackground)
            .cornerRadius(CampyRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: CampyRadius.large)
                    .stroke(isSelected ? CampyColors.accent : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Apple Pay Button
struct ApplePayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "apple.logo")
                Text("Pay")
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(CampyRadius.medium)
        }
    }
}

#Preview {
    WalletView()
        .environment(WalletManager())
        .environment(StoreKitManager())
}
