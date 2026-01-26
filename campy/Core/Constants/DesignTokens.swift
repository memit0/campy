//
//  DesignTokens.swift
//  campy
//
//  Design system tokens for consistent styling across the app
//

import SwiftUI

// MARK: - Colors
enum CampyColors {
    // Primary backgrounds
    static let background = Color(hex: "1C2D41")
    static let cardBackground = Color(hex: "243B53")
    static let sheetBackground = Color(hex: "2A4562")

    // Accent colors
    static let accent = Color(hex: "3B82C4")
    static let accentLight = Color(hex: "5BA3D9")
    static let accentDark = Color(hex: "2D6AA0")

    // Currency/coins
    static let currency = Color(hex: "F5A623")
    static let currencyGradientStart = Color(hex: "F5A623")
    static let currencyGradientEnd = Color(hex: "7CB342")

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "A0B3C6")
    static let textMuted = Color(hex: "6B8299")

    // Button colors
    static let buttonPrimary = Color(hex: "3B82C4")
    static let buttonSecondary = Color(hex: "243B53")
    static let buttonText = Color.white

    // Status colors
    static let success = Color(hex: "4CAF50")
    static let error = Color(hex: "F44336")
    static let warning = Color(hex: "FF9800")

    // Tab bar
    static let tabBarBackground = Color(hex: "1C2D41")
    static let tabSelected = Color(hex: "3B82C4")
    static let tabUnselected = Color(hex: "6B8299")

    // Session user avatars
    static let avatarColors: [Color] = [
        Color(hex: "E91E63"), // Pink
        Color(hex: "9C27B0"), // Purple
        Color(hex: "3F51B5"), // Indigo
        Color(hex: "4CAF50"), // Green
        Color(hex: "FF9800"), // Orange
        Color(hex: "00BCD4"), // Cyan
        Color(hex: "F44336"), // Red
        Color(hex: "FFEB3B"), // Yellow
    ]
}

// MARK: - Typography
enum CampyFonts {
    // Timer display
    static func timer(_ size: CGFloat = 72) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // Large titles (onboarding headers)
    static func largeTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // Headers
    static func header(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // Subheaders
    static func subheader(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // Body text
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    // Caption/small text
    static func caption(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    // Button text
    static func button(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // Balance display
    static func balance(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // Picker values
    static func picker(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func pickerSelected(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Spacing
enum CampySpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius
enum CampyRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 24
    static let pill: CGFloat = 25
    static let sheet: CGFloat = 32
    static let circular: CGFloat = 999
}

// MARK: - Shadows
enum CampyShadows {
    static let small = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let large = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Animation Durations
enum CampyAnimation {
    static let fast: Double = 0.15
    static let normal: Double = 0.3
    static let slow: Double = 0.5

    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let easeOut = Animation.easeOut(duration: normal)
    static let easeInOut = Animation.easeInOut(duration: normal)
}

// MARK: - Layout Constants
enum CampyLayout {
    static let buttonHeight: CGFloat = 56
    static let circularButtonSize: CGFloat = 140
    static let circularButtonRingSize: CGFloat = 180
    static let tabBarHeight: CGFloat = 80
    static let sheetHandleWidth: CGFloat = 40
    static let sheetHandleHeight: CGFloat = 4
    static let avatarSize: CGFloat = 32
    static let coinIconSize: CGFloat = 24
}

// MARK: - Bet & Time Options
enum CampyOptions {
    static let timeOptions: [Int] = [5, 10, 15, 20, 25] // minutes
    static let betOptions: [Int] = [5, 10, 15, 20, 25] // coins

    static let defaultTimeIndex: Int = 2 // 15 minutes
    static let defaultBetIndex: Int = 2 // 15 coins
}

// MARK: - Coin Packages
enum CampyCoinPackages {
    static let packages: [(coins: Int, price: String, productId: String)] = [
        (100, "$3.99", "com.campy.coins.100"),
        (500, "$5.99", "com.campy.coins.500"),
        (1000, "$7.99", "com.campy.coins.1000"),
        (1500, "$12.99", "com.campy.coins.1500"),
        (2000, "$15.99", "com.campy.coins.2000"),
        (2500, "$20.99", "com.campy.coins.2500"),
    ]
}
