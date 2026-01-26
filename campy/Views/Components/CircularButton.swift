//
//  CircularButton.swift
//  campy
//
//  Large circular button with ring effect (Start/Go button)
//

import SwiftUI

struct CircularButton: View {
    let title: String
    let action: () -> Void
    var size: CGFloat = CampyLayout.circularButtonSize
    var ringSize: CGFloat = CampyLayout.circularButtonRingSize

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                CampyColors.accent.opacity(0.6),
                                CampyColors.accentLight.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: ringSize, height: ringSize)

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                CampyColors.accent.opacity(0.15),
                                .clear
                            ],
                            center: .center,
                            startRadius: size / 2,
                            endRadius: ringSize / 2
                        )
                    )
                    .frame(width: ringSize, height: ringSize)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                CampyColors.cardBackground,
                                CampyColors.cardBackground.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                // Button text
                Text(title)
                    .font(CampyFonts.header(32))
                    .foregroundColor(CampyColors.textPrimary)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    ZStack {
        CampyColors.background.ignoresSafeArea()
        CircularButton(title: "Start") {
            print("Tapped")
        }
    }
}
