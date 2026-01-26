//
//  StartSessionView.swift
//  campy
//
//  Session setup view with time and bet pickers
//

import SwiftUI

struct StartSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager
    @Environment(BluetoothManager.self) private var bluetoothManager
    @Environment(GameManager.self) private var gameManager

    @State private var viewModel = SessionViewModel()
    @State private var showActiveSession = false

    var body: some View {
        ZStack {
            // Background image
            Image("trees-background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Gradient overlay for readability
            LinearGradient(
                colors: [
                    Color.clear,
                    CampyColors.background.opacity(0.8),
                    CampyColors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                // Header with balance
                HStack {
                    BalanceView(balance: walletManager.balance, style: .compact)
                    Spacer()
                }
                .padding(.horizontal, CampySpacing.lg)
                .padding(.top, CampySpacing.md)

                Spacer()

                // Bottom sheet content
                VStack(spacing: CampySpacing.lg) {
                    // Title based on picker mode
                    Text(viewModel.pickerMode == .time
                         ? "Set the time for your session"
                         : "Set the amount you would like to bet")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textPrimary)
                        .multilineTextAlignment(.center)

                    SheetDivider()

                    // Go button
                    CircularButton(title: "Go", action: startSession, size: 100, ringSize: 130)

                    // Picker
                    if viewModel.pickerMode == .time {
                        TimePicker(selectedIndex: $viewModel.selectedTimeIndex)
                    } else {
                        BetPicker(selectedIndex: $viewModel.selectedBetIndex)
                    }

                    // Toggle buttons
                    PickerToggle(mode: $viewModel.pickerMode)
                        .padding(.bottom, CampySpacing.lg)
                }
                .padding(.horizontal, CampySpacing.lg)
                .padding(.top, CampySpacing.lg)
                .background(
                    CampyColors.sheetBackground
                        .cornerRadius(CampyRadius.sheet, corners: [.topLeft, .topRight])
                )
            }
        }
        .onAppear {
            viewModel.walletManager = walletManager
            viewModel.bluetoothManager = bluetoothManager
            viewModel.gameManager = gameManager
        }
        .fullScreenCover(isPresented: $showActiveSession) {
            ActiveSessionView(viewModel: viewModel)
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

    private func startSession() {
        guard viewModel.hasSelectedTimeAndBet else {
            viewModel.error = "Please select both time and bet amount before starting."
            return
        }

        guard viewModel.canStartSession else {
            viewModel.error = "You need at least \(viewModel.selectedBet ?? 0) coins to start this session."
            return
        }

        viewModel.startSession()
        showActiveSession = true
    }
}

#Preview {
    StartSessionView()
        .environment(WalletManager())
        .environment(BluetoothManager())
        .environment(GameManager())
}
