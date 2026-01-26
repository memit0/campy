//
//  SettingsView.swift
//  campy
//
//  Settings modal with app preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            SheetHandle()
                .padding(.top, CampySpacing.md)

            // Header
            Text("Settings")
                .font(CampyFonts.header())
                .foregroundColor(CampyColors.textPrimary)
                .padding(.top, CampySpacing.lg)

            SheetDivider()
                .padding(.horizontal, CampySpacing.lg)

            // Settings list
            ScrollView {
                VStack(spacing: CampySpacing.sm) {
                    // Preferences section
                    SettingsSection(title: "Preferences") {
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            isOn: $notificationsEnabled
                        )

                        SettingsToggleRow(
                            icon: "speaker.wave.2.fill",
                            title: "Sound Effects",
                            isOn: $soundEnabled
                        )

                        SettingsToggleRow(
                            icon: "iphone.radiowaves.left.and.right",
                            title: "Haptic Feedback",
                            isOn: $hapticsEnabled
                        )
                    }

                    // About section
                    SettingsSection(title: "About") {
                        SettingsInfoRow(
                            icon: "info.circle.fill",
                            title: "Version",
                            value: appVersion
                        )
                    }
                }
                .padding(.horizontal, CampySpacing.lg)
            }

            Spacer()
        }
        .background(CampyColors.sheetBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CampySpacing.sm) {
            Text(title)
                .font(CampyFonts.caption())
                .foregroundColor(CampyColors.textSecondary)
                .padding(.leading, CampySpacing.sm)

            VStack(spacing: 1) {
                content
            }
            .background(CampyColors.cardBackground)
            .cornerRadius(CampyRadius.large)
        }
        .padding(.bottom, CampySpacing.md)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: CampySpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(CampyColors.accent)
                .frame(width: 24)

            Text(title)
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(CampyColors.accent)
                .labelsHidden()
        }
        .padding(.horizontal, CampySpacing.md)
        .padding(.vertical, CampySpacing.md)
    }
}

// MARK: - Settings Info Row
struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: CampySpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(CampyColors.accent)
                .frame(width: 24)

            Text(title)
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textPrimary)

            Spacer()

            Text(value)
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)
        }
        .padding(.horizontal, CampySpacing.md)
        .padding(.vertical, CampySpacing.md)
    }
}

#Preview {
    ZStack {
        CampyColors.background.ignoresSafeArea()

        SettingsView()
    }
}
