//
//  ActiveSessionView.swift
//  campy
//
//  Full-screen active game session view with timer
//

import SwiftUI

struct ActiveSessionView: View {
    @Bindable var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(GameManager.self) private var gameManager
    @Environment(AppLifecycleManager.self) private var appLifecycleManager

    @State private var showEndConfirmation = false
    @State private var showBluetoothError = false

    var body: some View {
        ZStack {
            // Background
            backgroundView

            VStack(spacing: 0) {
                // Header with balance and users
                headerView
                    .padding(.horizontal, CampySpacing.lg)
                    .padding(.top, CampySpacing.md)

                Spacer()

                // Timer display
                timerView

                Spacer()

                // Bet amount
                betView

                Spacer()
                    .frame(height: CampySpacing.xxxl)
            }

            // Game ended overlay
            if case .ended(let winner) = gameManager.state {
                GameEndedOverlay(didWin: winner) {
                    dismiss()
                }
            }
        }
        .onAppear {
            setupLifecycleCallbacks()
        }
        .alert("Leave Session?", isPresented: $showEndConfirmation) {
            Button("Stay", role: .cancel) {}
            Button("Leave", role: .destructive) {
                viewModel.reportLoss()
            }
        } message: {
            Text("Leaving the session means you lose the challenge and your bet.")
        }
        .alert("Bluetooth Error", isPresented: $showBluetoothError) {
            Button("OK", role: .cancel) {
                gameManager.bluetoothError = nil
            }
        } message: {
            Text(gameManager.bluetoothError?.localizedDescription ?? "An unknown Bluetooth error occurred.")
        }
        .onChange(of: gameManager.bluetoothError != nil) { _, hasError in
            showBluetoothError = hasError
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            // Trees background image
            Image("trees-background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Slight darkening overlay
            Color.black.opacity(0.2)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            // Balance
            BalanceView(balance: viewModel.walletManager?.balance ?? 0, style: .compact)

            Spacer()

            // Participant avatars
            VStack(alignment: .trailing, spacing: CampySpacing.xs) {
                Text("Users:")
                    .font(CampyFonts.caption())
                    .foregroundColor(CampyColors.textSecondary)

                AvatarStack(participants: viewModel.participants)
            }
        }
    }

    // MARK: - Timer

    private var timerView: some View {
        VStack(spacing: CampySpacing.sm) {
            Text(viewModel.formattedTimeRemaining)
                .font(CampyFonts.timer())
                .foregroundColor(CampyColors.textPrimary)
                .monospacedDigit()

            Text("Minutes left")
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)
        }
    }

    // MARK: - Bet Display

    private var betView: some View {
        HStack(spacing: CampySpacing.sm) {
            Text("\(viewModel.currentSession?.betAmount ?? 0)")
                .font(CampyFonts.header(32))
                .foregroundColor(CampyColors.textPrimary)

            CoinMascotView(size: 32)

            Text("On the line")
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)
        }
    }

    // MARK: - Setup

    private func setupLifecycleCallbacks() {
        appLifecycleManager.onAppBackgrounded = {
            // User left the app - they lose!
            viewModel.reportLoss()
        }
    }
}

// MARK: - Game Ended Overlay
struct GameEndedOverlay: View {
    let didWin: Bool
    let onDismiss: () -> Void

    @State private var showAnimation = false

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: CampySpacing.xl) {
                // Icon
                ZStack {
                    Circle()
                        .fill(didWin ? CampyColors.success : CampyColors.error)
                        .frame(width: 120, height: 120)
                        .scaleEffect(showAnimation ? 1 : 0.5)

                    Image(systemName: didWin ? "trophy.fill" : "xmark")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }

                // Title
                Text(didWin ? "You Won!" : "You Lost")
                    .font(CampyFonts.largeTitle())
                    .foregroundColor(CampyColors.textPrimary)

                // Subtitle
                Text(didWin
                     ? "Congratulations! Your winnings have been added to your wallet."
                     : "Better luck next time. Stay present!")
                    .font(CampyFonts.body())
                    .foregroundColor(CampyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CampySpacing.xl)

                Spacer()
                    .frame(height: CampySpacing.xl)

                // Done button
                PillButton(primary: "Done") {
                    onDismiss()
                }
                .padding(.horizontal, CampySpacing.xl)
            }
            .padding(.top, CampySpacing.xxxl)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showAnimation = true
            }

            // Play sound
            if didWin {
                SoundManager.shared.playSound(.victory)
                SoundManager.shared.triggerHaptic(.success)
            } else {
                SoundManager.shared.playSound(.loss)
                SoundManager.shared.triggerHaptic(.error)
            }
        }
    }
}

// MARK: - Waiting View
struct WaitingForPlayersView: View {
    let participantCount: Int
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: CampySpacing.xl) {
            // Pulsing indicator
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(CampyColors.accent.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(index * 30), height: 100 + CGFloat(index * 30))
                        .scaleEffect(1.0)
                        .opacity(0.5)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: UUID()
                        )
                }

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundColor(CampyColors.accent)
            }

            Text("Waiting for players...")
                .font(CampyFonts.header())
                .foregroundColor(CampyColors.textPrimary)

            Text("\(participantCount) player\(participantCount == 1 ? "" : "s") connected")
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)

            Spacer()
                .frame(height: CampySpacing.xl)

            Button("Cancel") {
                onCancel()
            }
            .font(CampyFonts.button())
            .foregroundColor(CampyColors.error)
        }
    }
}

#Preview {
    ActiveSessionView(viewModel: SessionViewModel())
        .environment(GameManager())
        .environment(AppLifecycleManager())
}
