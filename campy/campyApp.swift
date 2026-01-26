//
//  campyApp.swift
//  campy
//
//  Main entry point for the Campy app
//

import SwiftUI

@main
struct CampyApp: App {
    // State managers
    @State private var walletManager = WalletManager()
    @State private var bluetoothManager = BluetoothManager()
    @State private var gameManager = GameManager()
    @State private var storeKitManager = StoreKitManager()
    @State private var cloudKitManager = CloudKitManager()
    @State private var appLifecycleManager = AppLifecycleManager()

    // Onboarding state
    @State private var onboardingViewModel = OnboardingViewModel()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingContainerView(viewModel: onboardingViewModel) {
                        withAnimation {
                            showOnboarding = false
                        }
                    }
                } else {
                    MainTabView()
                }
            }
            .environment(walletManager)
            .environment(bluetoothManager)
            .environment(gameManager)
            .environment(storeKitManager)
            .environment(cloudKitManager)
            .environment(appLifecycleManager)
            .onAppear {
                setupManagers()
                checkOnboardingStatus()
            }
        }
    }

    private func setupManagers() {
        // TODO: CloudKit disabled temporarily - crashes on init
        // cloudKitManager.initialize()
        // walletManager.cloudKitManager = cloudKitManager

        // Connect managers to each other
        gameManager.bluetoothManager = bluetoothManager
        gameManager.walletManager = walletManager
        gameManager.appLifecycleManager = appLifecycleManager
        gameManager.setupBluetoothCallbacks()

        // Setup app lifecycle callbacks
        appLifecycleManager.onAppBackgrounded = {
            if gameManager.state == .playing {
                gameManager.reportLoss()
            }
        }

        // Load demo data for development
        #if DEBUG
        if walletManager.balance == 0 {
            walletManager.loadDemoData()
        }
        #endif
    }

    private func checkOnboardingStatus() {
        onboardingViewModel.checkOnboardingStatus()
        showOnboarding = !onboardingViewModel.hasCompletedOnboarding
    }
}
