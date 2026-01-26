//
//  BalanceView.swift
//  campy
//
//  Balance display component showing coin count
//

import SwiftUI

struct BalanceView: View {
    let balance: Int
    var style: BalanceStyle = .compact

    enum BalanceStyle {
        case compact    // Small pill for header
        case expanded   // Large display for wallet
    }

    var body: some View {
        switch style {
        case .compact:
            compactView
        case .expanded:
            expandedView
        }
    }

    private var compactView: some View {
        HStack(spacing: CampySpacing.xs) {
            Text(formattedBalance)
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textPrimary)

            coinIcon(size: 16)
        }
        .padding(.horizontal, CampySpacing.md)
        .padding(.vertical, CampySpacing.sm)
        .background(CampyColors.cardBackground)
        .cornerRadius(CampyRadius.pill)
    }

    private var expandedView: some View {
        VStack(spacing: CampySpacing.sm) {
            Text("Available Balance")
                .font(CampyFonts.body())
                .foregroundColor(CampyColors.textSecondary)

            HStack(spacing: CampySpacing.sm) {
                Text(formattedBalance)
                    .font(CampyFonts.balance())
                    .foregroundColor(CampyColors.textPrimary)
            }
        }
    }

    private func coinIcon(size: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [CampyColors.currencyGradientStart, CampyColors.currencyGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
    }
}

// MARK: - Coin Mascot View
struct CoinMascotView: View {
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            // Coin body
            Circle()
                .fill(
                    LinearGradient(
                        colors: [CampyColors.currencyGradientStart, CampyColors.currencyGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Face
            VStack(spacing: size * 0.05) {
                // Eyes
                HStack(spacing: size * 0.15) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.06, height: size * 0.06)
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.06, height: size * 0.06)
                }

                // Smile
                Path { path in
                    let smileWidth = size * 0.25
                    let smileHeight = size * 0.08
                    path.move(to: CGPoint(x: -smileWidth/2, y: 0))
                    path.addQuadCurve(
                        to: CGPoint(x: smileWidth/2, y: 0),
                        control: CGPoint(x: 0, y: smileHeight)
                    )
                }
                .stroke(Color.black, lineWidth: 2)
                .frame(width: size * 0.3, height: size * 0.1)
            }
            .offset(y: -size * 0.05)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        BalanceView(balance: 3284, style: .compact)
        BalanceView(balance: 3284, style: .expanded)
        CoinMascotView()
    }
    .padding()
    .background(CampyColors.background)
}
