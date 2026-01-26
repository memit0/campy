//
//  OnboardingViewModel.swift
//  campy
//
//  ViewModel for onboarding flow
//

import SwiftUI
import UserNotifications

@Observable
class OnboardingViewModel {
    var currentPage: Int = 0
    var hasCompletedOnboarding: Bool = false
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let totalPages = 5

    var isLastPage: Bool {
        currentPage == totalPages - 1
    }

    var isNotificationPage: Bool {
        currentPage == 1
    }

    func nextPage() {
        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        }
    }

    func previousPage() {
        if currentPage > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage -= 1
            }
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func checkOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Notifications

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                notificationStatus = granted ? .authorized : .denied
                nextPage()
            }
        } catch {
            await MainActor.run {
                notificationStatus = .denied
                nextPage()
            }
        }
    }

    func skipNotifications() {
        nextPage()
    }

    func checkNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            notificationStatus = settings.authorizationStatus
        }
    }
}

// MARK: - Onboarding Page Content
struct OnboardingPageContent {
    let title: String
    let subtitle: String?
    let imageName: String?

    static let pages: [OnboardingPageContent] = [
        OnboardingPageContent(
            title: "Put the phone down and pick up the moment.",
            subtitle: "Some memories are better lived than scrolled.",
            imageName: "onboarding-1"
        ),
        OnboardingPageContent(
            title: "Your friends are right here. Put the phone down and don't miss this moment.",
            subtitle: "Allow notifications to let us remind you.",
            imageName: "onboarding-2"
        ),
        OnboardingPageContent(
            title: "Create a challenge with friends",
            subtitle: "Connect with nearby friends and start a phone-free challenge together.",
            imageName: "onboarding-3"
        ),
        OnboardingPageContent(
            title: "Phones stay down. First phone pays.",
            subtitle: "The first person to leave the app loses and pays the others.",
            imageName: "onboarding-4"
        ),
        OnboardingPageContent(
            title: "Stay present together",
            subtitle: "Make memories that matter. Put the phones away and enjoy the moment.",
            imageName: "onboarding-5"
        )
    ]
}
