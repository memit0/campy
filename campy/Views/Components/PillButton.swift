//
//  PillButton.swift
//  campy
//
//  Pill-shaped button component
//

import SwiftUI

struct PillButton: View {
    let title: String
    let style: PillButtonStyle
    let action: () -> Void

    @State private var isPressed = false

    enum PillButtonStyle {
        case primary
        case secondary
        case outline

        var backgroundColor: Color {
            switch self {
            case .primary:
                return CampyColors.buttonPrimary
            case .secondary:
                return CampyColors.buttonSecondary
            case .outline:
                return .clear
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .secondary:
                return CampyColors.textPrimary
            case .outline:
                return CampyColors.textPrimary
            }
        }

        var borderColor: Color {
            switch self {
            case .outline:
                return CampyColors.textSecondary
            default:
                return .clear
            }
        }
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            Text(title)
                .font(CampyFonts.button())
                .foregroundColor(style.foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: CampyLayout.buttonHeight)
                .background(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: CampyRadius.pill)
                        .stroke(style.borderColor, lineWidth: style == .outline ? 2 : 0)
                )
                .cornerRadius(CampyRadius.pill)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Convenience Initializers
extension PillButton {
    init(primary title: String, action: @escaping () -> Void) {
        self.title = title
        self.style = .primary
        self.action = action
    }

    init(secondary title: String, action: @escaping () -> Void) {
        self.title = title
        self.style = .secondary
        self.action = action
    }

    init(outline title: String, action: @escaping () -> Void) {
        self.title = title
        self.style = .outline
        self.action = action
    }
}

#Preview {
    VStack(spacing: 20) {
        PillButton(primary: "Next") {}
        PillButton(secondary: "Add Funds") {}
        PillButton(outline: "Later") {}
    }
    .padding()
    .background(CampyColors.background)
}
