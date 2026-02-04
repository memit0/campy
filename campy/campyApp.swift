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
        // Initialize CloudKit with comprehensive error handling
        // CloudKit initialization is now safe and won't crash - errors are logged and handled gracefully
        initializeCloudKit()

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

    private func initializeCloudKit() {
        #if DEBUG
        print("☁️ [App] Starting CloudKit initialization...")
        #endif

        // Initialize CloudKit - this is now safe and handles all errors gracefully
        cloudKitManager.initialize()

        // Connect CloudKit to wallet manager for data sync
        walletManager.cloudKitManager = cloudKitManager

        #if DEBUG
        // Log the initialization state for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [cloudKitManager] in
            print("☁️ [App] CloudKit state after 1s: \(cloudKitManager.initializationState)")
            print("☁️ [App] CloudKit available: \(cloudKitManager.isAvailable)")
            if let error = cloudKitManager.lastError {
                print("☁️ [App] CloudKit error: \(error.localizedDescription)")
            }
        }
        #endif
    }

    private func checkOnboardingStatus() {
        onboardingViewModel.checkOnboardingStatus()
        showOnboarding = !onboardingViewModel.hasCompletedOnboarding
    }
}
