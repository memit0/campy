//
//  MainTabView.swift
//  campy
//
//  Main tab view container for Home and Wallet
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var homeViewModel = HomeViewModel()

    @Environment(WalletManager.self) private var walletManager
    @Environment(BluetoothManager.self) private var bluetoothManager
    @Environment(GameManager.self) private var gameManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            CampyColors.background
                .ignoresSafeArea()

            // Tab content
            Group {
                switch selectedTab {
                case .home:
                    HomeView(viewModel: homeViewModel)
                case .wallet:
                    WalletView()
                }
            }
            .padding(.bottom, CampyLayout.tabBarHeight)

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .onAppear {
            homeViewModel.walletManager = walletManager
            homeViewModel.bluetoothManager = bluetoothManager
        }
    }
}

#Preview {
    MainTabView()
        .environment(WalletManager())
        .environment(BluetoothManager())
        .environment(GameManager())
}
