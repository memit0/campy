//
//  CustomTabBar.swift
//  campy
//
//  Custom tab bar component matching the design
//

import SwiftUI

enum TabItem: Int, CaseIterable {
    case home
    case wallet

    var title: String {
        switch self {
        case .home: return "Home"
        case .wallet: return "Wallet"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .wallet: return "wallet.pass.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        HStack(spacing: 0) {
            // Menu button
            Button(action: {
                // Menu action
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(CampyColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(CampyColors.cardBackground)
                    .clipShape(Circle())
            }
            .padding(.leading, CampySpacing.md)

            Spacer()

            // Tab buttons
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.rawValue) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(4)
            .background(CampyColors.cardBackground)
            .cornerRadius(CampyRadius.pill)

            Spacer()

            // Spacer to balance the menu button
            Color.clear
                .frame(width: 44, height: 44)
                .padding(.trailing, CampySpacing.md)
        }
        .frame(height: CampyLayout.tabBarHeight)
        .background(CampyColors.background)
    }
}

struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.title)
                .font(CampyFonts.button(16))
                .foregroundColor(isSelected ? CampyColors.textPrimary : CampyColors.textSecondary)
                .padding(.horizontal, CampySpacing.lg)
                .padding(.vertical, CampySpacing.sm)
                .background(
                    isSelected ? CampyColors.accent : Color.clear
                )
                .cornerRadius(CampyRadius.pill)
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var selectedTab: TabItem = .home

        var body: some View {
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
            .background(CampyColors.background)
        }
    }

    return PreviewContainer()
}
