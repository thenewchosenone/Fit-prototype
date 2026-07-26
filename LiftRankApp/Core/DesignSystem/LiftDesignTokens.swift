import SwiftUI

extension Color {
    static let liftLime = Color(red: 0xC7 / 255, green: 0xFF / 255, blue: 0x00 / 255)
    static let liftOrange = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x22 / 255)
    static let liftOnAccent = Color(red: 0x08 / 255, green: 0x0A / 255, blue: 0x0D / 255)

    private static func semantic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    static let liftSurfaceBackground = semantic(
        light: UIColor(red: 0xF7 / 255, green: 0xF8 / 255, blue: 0xFB / 255, alpha: 1),
        dark: UIColor(red: 0x11 / 255, green: 0x11 / 255, blue: 0x13 / 255, alpha: 1)
    )

    static let liftSurfaceElevated = semantic(
        light: .white,
        dark: UIColor(red: 0x1C / 255, green: 0x1D / 255, blue: 0x20 / 255, alpha: 1)
    )

    static let liftSurfaceSecondary = semantic(
        light: UIColor(red: 0xE8 / 255, green: 0xEA / 255, blue: 0xEE / 255, alpha: 1),
        dark: UIColor(red: 0x24 / 255, green: 0x25 / 255, blue: 0x2A / 255, alpha: 1)
    )

    static let liftSurfaceBorder = semantic(
        light: UIColor.black.withAlphaComponent(0.09),
        dark: UIColor.white.withAlphaComponent(0.12)
    )

    static let liftBackground = semantic(
        light: .white,
        dark: UIColor(red: 0x11 / 255, green: 0x11 / 255, blue: 0x13 / 255, alpha: 1)
    )

    static let liftCard = semantic(
        light: UIColor(red: 0xE8 / 255, green: 0xEA / 255, blue: 0xEE / 255, alpha: 1),
        dark: UIColor(red: 0x24 / 255, green: 0x25 / 255, blue: 0x2A / 255, alpha: 1)
    )

    static let liftCardRaised = semantic(
        light: UIColor(red: 0xD2 / 255, green: 0xD6 / 255, blue: 0xE0 / 255, alpha: 1),
        dark: UIColor(red: 0x1C / 255, green: 0x1D / 255, blue: 0x20 / 255, alpha: 1)
    )

    static let liftText = semantic(
        light: UIColor(red: 0.055, green: 0.065, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
    )

    static let liftMuted = semantic(
        light: UIColor(red: 0x5A / 255, green: 0x63 / 255, blue: 0x73 / 255, alpha: 1),
        dark: UIColor(red: 0xA4 / 255, green: 0xA5 / 255, blue: 0xAD / 255, alpha: 1)
    )

    static let liftTextPrimary = liftText
    static let liftTextSecondary = liftMuted
    static let liftTextDisabled = semantic(
        light: UIColor(red: 0xA8 / 255, green: 0xAE / 255, blue: 0xBA / 255, alpha: 1),
        dark: UIColor(red: 0x66 / 255, green: 0x68 / 255, blue: 0x70 / 255, alpha: 1)
    )

    static let liftBlue = liftLime
    static let liftPurple = Color(red: 0.74, green: 0.66, blue: 0.98)
    static let liftGreen = Color(red: 0.36, green: 0.92, blue: 0.65)
    static let liftGold = Color(red: 1.0, green: 0.80, blue: 0.28)
    static let liftSilver = Color(red: 0.72, green: 0.74, blue: 0.78)
    static let liftBronze = Color(red: 0.74, green: 0.46, blue: 0.24)
    static let liftRed = Color(red: 0.92, green: 0.27, blue: 0.38)
    static let liftSeparator = semantic(
        light: UIColor.black.withAlphaComponent(0.09),
        dark: UIColor(red: 1, green: 1, blue: 1, alpha: 0.12)
    )
    static let liftField = semantic(
        light: UIColor(red: 0.94, green: 0.948, blue: 0.965, alpha: 1),
        dark: UIColor(red: 0x14 / 255, green: 0x16 / 255, blue: 0x1B / 255, alpha: 1)
    )
}

enum LiftAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum LiftDesign {
    static let cardRadius: CGFloat = 28
    static let controlRadius: CGFloat = 14
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let screenHorizontalPadding: CGFloat = 22
    static let minimumTouchTarget: CGFloat = 44
}

enum LiftMotion {
    static let quick = Animation.easeOut(duration: 0.2)
    static let spring = Animation.spring(response: 0.27, dampingFraction: 0.88)
}
