import SwiftUI
import Observation

enum LiftAccent: String, CaseIterable, Identifiable {
    case lime = "Lime", orange = "Orange", red = "Red", pink = "Pink"
    case purple = "Purple", blue = "Blue", teal = "Teal", green = "Green"
    case crimsonPink = "Crimson Pink", tropicalMint = "Tropical Mint", crestYellow = "Crest Yellow"

    var id: String { rawValue }

    private var colors: (fill: UInt32, lightText: UInt32) {
        switch self {
        case .lime: (0xC7FF00, 0x485D00)
        case .orange: (0xFFB27F, 0x914100)
        case .red: (0xFF9B9E, 0xA0162D)
        case .pink: (0xFF9FD0, 0x94124F)
        case .purple: (0xC9B0FF, 0x59329C)
        case .blue: (0x9BC8FF, 0x1556A0)
        case .teal: (0x83DED5, 0x00615A)
        case .green: (0x9BE3A3, 0x19612D)
        case .crimsonPink: (0xFF6E88, 0x9B173B)
        case .tropicalMint: (0x85F9C0, 0x006343)
        case .crestYellow: (0xEDF354, 0x505900)
        }
    }

    var control: Color {
        let light: UInt32 = switch self {
        case .lime: 0x628000
        case .orange: 0xBD5200
        case .red: 0xCE3048
        case .pink: 0xBD2470
        case .purple: 0x7847C8
        case .blue: 0x246DC0
        case .teal: 0x007F76
        case .green: 0x25823E
        case .crimsonPink: 0xC52A50
        case .tropicalMint: 0x007F55
        case .crestYellow: 0x747D00
        }
        let dark = colors.fill
        return Color(uiColor: UIColor { traits in
            liftUIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    var fill: Color { Color(uiColor: liftUIColor(colors.fill)) }
    var text: Color {
        let light = liftUIColor(colors.lightText)
        let dark = liftUIColor(colors.fill)
        return Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

private func liftUIColor(_ value: UInt32) -> UIColor {
    UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

fileprivate struct LiftThemePalette {
    let background: (light: UInt32, dark: UInt32)
    let card: (light: UInt32, dark: UInt32)
    let raised: (light: UInt32, dark: UInt32)
    let elevated: (light: UInt32, dark: UInt32)
    let secondary: (light: UInt32, dark: UInt32)
    let field: (light: UInt32, dark: UInt32)
    let text: (light: UInt32, dark: UInt32)
    let muted: (light: UInt32, dark: UInt32)
    let border: UInt32
}

enum LiftTheme: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case sealNavy = "Seal & Navy"
    case onyxIndigo = "Onyx & Indigo"
    case mandarinForest = "Mandarin & Forest"

    var id: String { rawValue }

    var swatches: [Color] {
        let values: [UInt32] = switch self {
        case .classic: [0x111113, 0xFFFFFF, 0xC7FF00]
        case .sealNavy: [0xD6F2FC, 0x072D59, 0xFF6E88]
        case .onyxIndigo: [0x01010D, 0x6331FB, 0x85F9C0]
        case .mandarinForest: [0xFD550A, 0x015D47, 0xEDF354]
        }
        return values.map { Color(uiColor: liftUIColor($0)) }
    }

    var defaultAccent: LiftAccent {
        switch self {
        case .classic: .lime
        case .sealNavy: .crimsonPink
        case .onyxIndigo: .tropicalMint
        case .mandarinForest: .crestYellow
        }
    }

    fileprivate var palette: LiftThemePalette {
        switch self {
        case .classic:
            LiftThemePalette(background: (0xFFFFFF, 0x111113), card: (0xE8EAEE, 0x24252A),
                             raised: (0xD2D6E0, 0x1C1D20), elevated: (0xFFFFFF, 0x1C1D20),
                             secondary: (0xE8EAEE, 0x24252A), field: (0xF0F2F6, 0x14161B),
                             text: (0x0E111A, 0xF5F5F7), muted: (0x505967, 0xA4A5AD), border: 0xFFFFFF)
        case .sealNavy:
            LiftThemePalette(background: (0xD6F2FC, 0x071B34), card: (0xEDF8FD, 0x072D59),
                             raised: (0xBDDDEE, 0x0D365D), elevated: (0xF6FCFF, 0x0C355F),
                             secondary: (0xBEDDEA, 0x0D365D), field: (0xE6F5FB, 0x0A294D),
                             text: (0x072D59, 0xECF7FD), muted: (0x3D617C, 0xBED4E2), border: 0x072D59)
        case .onyxIndigo:
            LiftThemePalette(background: (0xF6F4FF, 0x01010D), card: (0xE9E2FF, 0x1B0E3D),
                             raised: (0xD7C8FF, 0x2A155A), elevated: (0xFFFFFF, 0x180C35),
                             secondary: (0xE0D4FF, 0x23134B), field: (0xF0EBFF, 0x120A2B),
                             text: (0x01010D, 0xFAF9FF), muted: (0x514A70, 0xB5AED5), border: 0x6331FB)
        case .mandarinForest:
            LiftThemePalette(background: (0xEDF6EF, 0x00251D), card: (0xE0EDE5, 0x00382B),
                             raised: (0xCEE3D6, 0x003D30), elevated: (0xF5FAF6, 0x003C2F),
                             secondary: (0xD7E9DD, 0x003A2D), field: (0xF1F8F3, 0x003127),
                             text: (0x015D47, 0xFAFCEB), muted: (0x48695D, 0xBCD8CB), border: 0xFD550A)
        }
    }
}

@Observable
final class LiftThemeSelection {
    static let shared = LiftThemeSelection()
    private static let storageKey = "liftrank.theme"

    var value: LiftTheme {
        didSet { UserDefaults.standard.set(value.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        value = LiftTheme(rawValue: UserDefaults.standard.string(forKey: Self.storageKey) ?? "") ?? .classic
    }
}

@Observable
final class LiftAccentSelection {
    static let shared = LiftAccentSelection()
    private static let storageKey = "liftrank.accent"

    var value: LiftAccent {
        didSet { UserDefaults.standard.set(value.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        value = LiftAccent(rawValue: UserDefaults.standard.string(forKey: Self.storageKey) ?? "") ?? .lime
    }
}

extension Color {
    static var liftLime: Color { LiftAccentSelection.shared.value.fill }
    static let liftOrange = semantic(
        light: liftUIColor(0x983000),
        dark: liftUIColor(0xFF9B5E)
    )
    static let liftOnAccent = Color(red: 0x08 / 255, green: 0x0A / 255, blue: 0x0D / 255)
    static let liftOnGreen = semantic(
        light: .white,
        dark: UIColor(red: 0x08 / 255, green: 0x0A / 255, blue: 0x0D / 255, alpha: 1)
    )

    private static func semantic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    private static func themed(_ keyPath: KeyPath<LiftThemePalette, (light: UInt32, dark: UInt32)>) -> Color {
        let colors = LiftThemeSelection.shared.value.palette[keyPath: keyPath]
        return semantic(light: liftUIColor(colors.light), dark: liftUIColor(colors.dark))
    }

    static var liftSurfaceElevated: Color { themed(\.elevated) }

    static var liftSurfaceSecondary: Color { themed(\.secondary) }

    static var liftSurfaceBorder: Color {
        let theme = LiftThemeSelection.shared.value
        guard theme != .classic else {
            return semantic(light: UIColor.black.withAlphaComponent(0.09),
                            dark: UIColor.white.withAlphaComponent(0.12))
        }
        let border = liftUIColor(theme.palette.border)
        return semantic(light: border.withAlphaComponent(0.22), dark: border.withAlphaComponent(0.38))
    }

    static var liftBackground: Color { themed(\.background) }

    static var liftCard: Color { themed(\.card) }

    static var liftCardRaised: Color { themed(\.raised) }

    static var liftText: Color { themed(\.text) }

    static var liftMuted: Color { themed(\.muted) }

    static var liftTextPrimary: Color { liftText }
    static var liftTextSecondary: Color { liftMuted }
    static var liftControlTint: Color { LiftAccentSelection.shared.value.control }
    static var liftAccentText: Color { LiftAccentSelection.shared.value.text }
    static var liftTextDisabled: Color {
        LiftThemeSelection.shared.value == .classic
            ? semantic(light: liftUIColor(0xA8AEBA), dark: liftUIColor(0x666870))
            : liftMuted.opacity(0.7)
    }

    static var liftBlue: Color { liftLime }
    static let liftPurple = semantic(
        light: UIColor(red: 0.36, green: 0.25, blue: 0.66, alpha: 1),
        dark: UIColor(red: 0.74, green: 0.66, blue: 0.98, alpha: 1)
    )
    static let liftGreen = semantic(
        light: liftUIColor(0x00652E),
        dark: UIColor(red: 0.36, green: 0.92, blue: 0.65, alpha: 1)
    )
    static let liftGold = semantic(
        light: liftUIColor(0x7D4D00),
        dark: UIColor(red: 1.0, green: 0.80, blue: 0.28, alpha: 1)
    )
    static let liftSilver = semantic(
        light: UIColor(red: 0.32, green: 0.35, blue: 0.41, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1)
    )
    static let liftBronze = semantic(
        light: UIColor(red: 0.48, green: 0.25, blue: 0.09, alpha: 1),
        dark: liftUIColor(0xD6A376)
    )
    static let liftRed = semantic(
        light: UIColor(red: 0.68, green: 0.08, blue: 0.18, alpha: 1),
        dark: liftUIColor(0xFF8190)
    )
    static let liftSeparator = semantic(
        light: UIColor.black.withAlphaComponent(0.09),
        dark: UIColor(red: 1, green: 1, blue: 1, alpha: 0.12)
    )
    static let liftOverlay = semantic(
        light: UIColor.black.withAlphaComponent(0.06),
        dark: UIColor.white.withAlphaComponent(0.08)
    )
    static let liftScrim = semantic(
        light: UIColor.black.withAlphaComponent(0.18),
        dark: UIColor.black.withAlphaComponent(0.34)
    )
    static var liftField: Color { themed(\.field) }
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
    static let screenHorizontalPadding: CGFloat = 22
    static let minimumTouchTarget: CGFloat = 44
    static let floatingTabBarContentClearance: CGFloat = 104
}

enum LiftTypography {
    static let sectionTitle = Font.title3.weight(.semibold)
    static let cardTitle = Font.headline.weight(.semibold)
    static let rowEmphasis = Font.subheadline.weight(.semibold)
    static let compactEmphasis = Font.caption.weight(.semibold)
}

enum LiftMotion {
    static let quick = Animation.easeOut(duration: 0.2)
    static let spring = Animation.spring(response: 0.27, dampingFraction: 0.88)
}
