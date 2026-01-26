//
//  AppLifecycleManager.swift
//  campy
//
//  Monitors app lifecycle to detect when user leaves the app
//

import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

@Observable
class AppLifecycleManager {
    private(set) var isMonitoring = false
    private(set) var isInForeground = true
    private(set) var didLoseGame = false

    var onAppBackgrounded: (() -> Void)?
    var onAppForegrounded: (() -> Void)?

    private var audioPlayer: AVAudioPlayer?

    init() {
        setupNotifications()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        isMonitoring = true
        didLoseGame = false
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        if isMonitoring {
            // User is leaving the app - they lose!
            isInForeground = false
            didLoseGame = true
            onAppBackgrounded?()
        }
    }

    @objc private func appDidEnterBackground() {
        isInForeground = false
    }

    @objc private func appWillEnterForeground() {
        isInForeground = true
    }

    @objc private func appDidBecomeActive() {
        isInForeground = true
        onAppForegrounded?()
    }

    // MARK: - Victory Celebration

    func playVictorySound() {
        // Play system sound
        AudioServicesPlaySystemSound(1016) // Tweet sound

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func playLossSound() {
        // Play system sound
        AudioServicesPlaySystemSound(1053) // Tock sound

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    func playCountdownTick() {
        AudioServicesPlaySystemSound(1104) // Tick sound

        // Light haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func playGameStartSound() {
        AudioServicesPlaySystemSound(1117) // Begin recording sound

        // Medium haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Airplane Mode Check

    func checkAirplaneMode() -> Bool {
        // Note: iOS doesn't provide a direct API for airplane mode
        // We can only suggest the user enables it
        return false
    }

    func showAirplaneModeReminder() {
        // This should be called before the game starts
        // The UI should show a reminder to enable airplane mode
    }
}

// MARK: - Sound Manager Helper
class SoundManager {
    static let shared = SoundManager()

    private init() {}

    func playSound(_ soundType: SoundType) {
        switch soundType {
        case .victory:
            AudioServicesPlaySystemSound(1016)
        case .loss:
            AudioServicesPlaySystemSound(1053)
        case .tick:
            AudioServicesPlaySystemSound(1104)
        case .gameStart:
            AudioServicesPlaySystemSound(1117)
        case .notification:
            AudioServicesPlaySystemSound(1007)
        }
    }

    func triggerHaptic(_ type: HapticType) {
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }

    enum SoundType {
        case victory
        case loss
        case tick
        case gameStart
        case notification
    }

    enum HapticType {
        case success
        case error
        case warning
        case light
        case medium
        case heavy
    }
}
