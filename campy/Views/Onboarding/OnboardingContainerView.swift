//
//  OnboardingContainerView.swift
//  campy
//
//  Container view for onboarding flow with page navigation
//

import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            CampyColors.background
                .ignoresSafeArea()

            // Pages
            TabView(selection: $viewModel.currentPage) {
                OnboardingPage1View(viewModel: viewModel)
                    .tag(0)

                OnboardingPage2View(viewModel: viewModel)
                    .tag(1)

                OnboardingPage3View(viewModel: viewModel)
                    .tag(2)

                OnboardingPage4View(viewModel: viewModel)
                    .tag(3)

                OnboardingPage5View(viewModel: viewModel, onComplete: onComplete)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
        }
    }
}

// MARK: - Page 1: Welcome
struct OnboardingPage1View: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Image fills top portion
                Image("onboarding-1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.55)
                    .clipped()

                // Content at bottom
                VStack(spacing: CampySpacing.md) {
                    Text("Put the phone down and pick up the moment.")
                        .font(CampyFonts.header(28))
                        .foregroundColor(CampyColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Some memories are better lived than scrolled.")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.top, CampySpacing.lg)

                Spacer()

                PillButton(primary: "Next") {
                    viewModel.nextPage()
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.bottom, CampySpacing.xxl)
            }
        }
    }
}

// MARK: - Page 2: Notifications
struct OnboardingPage2View: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Image fills top portion
                Image("onboarding-2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
                    .clipped()

                // Content at bottom
                VStack(spacing: CampySpacing.md) {
                    Text("Your friends are right here.\nPut the phone down and don't miss this moment.")
                        .font(CampyFonts.header(24))
                        .foregroundColor(CampyColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Allow notifications to let us remind you.")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.top, CampySpacing.lg)

                Spacer()

                VStack(spacing: CampySpacing.md) {
                    PillButton(primary: "Allow") {
                        Task {
                            await viewModel.requestNotificationPermission()
                        }
                    }

                    PillButton(outline: "Later") {
                        viewModel.skipNotifications()
                    }
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.bottom, CampySpacing.xxl)
            }
        }
    }
}

// MARK: - Page 3: Create Challenge
struct OnboardingPage3View: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Image fills top portion
                Image("onboarding-3")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.55)
                    .clipped()

                // Content at bottom
                VStack(spacing: CampySpacing.md) {
                    Text("Create a challenge with friends")
                        .font(CampyFonts.header(28))
                        .foregroundColor(CampyColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Connect with nearby friends and start a phone-free challenge together.")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.top, CampySpacing.lg)

                Spacer()

                PillButton(primary: "Next") {
                    viewModel.nextPage()
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.bottom, CampySpacing.xxl)
            }
        }
    }
}

// MARK: - Page 4: Rules
struct OnboardingPage4View: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Image fills top portion
                Image("onboarding-4")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.55)
                    .clipped()

                // Content at bottom
                VStack(spacing: CampySpacing.md) {
                    Text("Phones stay down.\nFirst phone pays.")
                        .font(CampyFonts.header(28))
                        .foregroundColor(CampyColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("The first person to leave the app loses and pays the others.")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.top, CampySpacing.lg)

                Spacer()

                PillButton(primary: "Next") {
                    viewModel.nextPage()
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.bottom, CampySpacing.xxl)
            }
        }
    }
}

// MARK: - Page 5: Finale
struct OnboardingPage5View: View {
    let viewModel: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Image fills top portion
                Image("onboarding-5")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.55)
                    .clipped()

                // Content at bottom
                VStack(spacing: CampySpacing.md) {
                    Text("Stay present together")
                        .font(CampyFonts.header(28))
                        .foregroundColor(CampyColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Make memories that matter. Put the phones away and enjoy the moment.")
                        .font(CampyFonts.body())
                        .foregroundColor(CampyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.top, CampySpacing.lg)

                Spacer()

                PillButton(primary: "Get Started") {
                    viewModel.completeOnboarding()
                    onComplete()
                }
                .padding(.horizontal, CampySpacing.xl)
                .padding(.bottom, CampySpacing.xxl)
            }
        }
    }
}

#Preview {
    OnboardingContainerView(
        viewModel: OnboardingViewModel(),
        onComplete: {}
    )
}
