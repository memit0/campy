//
//  HomeView.swift
//  campy
//
//  Main home screen with mascot and start button
//

import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(WalletManager.self) private var walletManager
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background
            CampyColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with balance and settings
                headerView
                    .padding(.horizontal, CampySpacing.lg)
                    .padding(.top, CampySpacing.md)

                Spacer()

                // Greeting text
                VStack(spacing: CampySpacing.xs) {
                    Text("Hi!")
                        .font(CampyFonts.header())
                        .foregroundColor(CampyColors.textPrimary)

                    Text("Time to cherish this moment with friends")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CampySpacing.xl)

                Spacer()

                // Mascot
                mascotView

                Spacer()

                // Start button
                CircularButton(title: "Start") {
                    viewModel.startHosting()
                }

                Spacer()
                    .frame(height: CampySpacing.xxxl)
            }
        }
        .sheet(isPresented: $viewModel.showStartSession) {
            StartSessionView()
        }
        .sheet(isPresented: $viewModel.showJoinSession) {
            JoinSessionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var headerView: some View {
        HStack {
            // Balance
            BalanceView(balance: walletManager.balance, style: .compact)

            Spacer()

            // Settings button
            Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundColor(CampyColors.textSecondary)
            }
        }
    }

    private var mascotView: some View {
        Image("campy-mascot")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280, maxHeight: 280)
    }
}

// MARK: - Join Session Sheet
struct JoinSessionSheet: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            SheetHandle()
                .padding(.top, CampySpacing.md)

            // Header
            Text("Active Sessions")
                .font(CampyFonts.header())
                .foregroundColor(CampyColors.textPrimary)
                .padding(.top, CampySpacing.lg)

            SheetDivider()
                .padding(.horizontal, CampySpacing.lg)

            // Content
            if viewModel.nearbySessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }

            Spacer()

            // Share button
            PillButton(primary: "Share with Friends") {
                // Share action
            }
            .padding(.horizontal, CampySpacing.lg)
            .padding(.bottom, CampySpacing.xl)
        }
        .background(CampyColors.sheetBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            viewModel.startSearchingForSessions()
        }
        .onDisappear {
            viewModel.stopSearchingForSessions()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: CampySpacing.md) {
            Spacer()

            Text("There are no active sessions currently near you.")
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CampySpacing.xl)

            Spacer()
        }
    }

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: CampySpacing.md) {
                ForEach(viewModel.nearbySessions) { session in
                    SessionRow(session: session) {
                        viewModel.connectToSession(session)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, CampySpacing.lg)
        }
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: NearbySession
    let onJoin: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: CampySpacing.xs) {
                Text(session.hostName)
                    .font(CampyFonts.body())
                    .foregroundColor(CampyColors.textPrimary)

                HStack(spacing: CampySpacing.md) {
                    Label(session.formattedDuration, systemImage: "clock")
                    Label(session.formattedBet, systemImage: "dollarsign.circle")
                }
                .font(CampyFonts.caption())
                .foregroundColor(CampyColors.textSecondary)
            }

            Spacer()

            Button("Join") {
                onJoin()
            }
            .font(CampyFonts.button(14))
            .foregroundColor(CampyColors.textPrimary)
            .padding(.horizontal, CampySpacing.md)
            .padding(.vertical, CampySpacing.sm)
            .background(CampyColors.accent)
            .cornerRadius(CampyRadius.pill)
        }
        .padding(CampySpacing.md)
        .background(CampyColors.cardBackground)
        .cornerRadius(CampyRadius.large)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
        .environment(WalletManager())
}
