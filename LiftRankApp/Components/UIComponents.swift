import Foundation
import SwiftUI
import UIKit

extension Color {
    static let liftBackground = Color(red: 0.055, green: 0.067, blue: 0.11)
    static let liftCard = Color(red: 0.105, green: 0.122, blue: 0.19)
    static let liftCardRaised = Color(red: 0.145, green: 0.165, blue: 0.25)
    static let liftMuted = Color(red: 0.56, green: 0.59, blue: 0.68)
    static let liftBlue = Color(red: 0.22, green: 0.40, blue: 1.0)
    static let liftPurple = Color(red: 0.29, green: 0.36, blue: 0.95)
    static let liftGreen = Color(red: 0.09, green: 0.72, blue: 0.55)
    static let liftGold = Color(red: 1.0, green: 0.76, blue: 0.22)
    static let liftSilver = Color(red: 0.72, green: 0.74, blue: 0.78)
    static let liftBronze = Color(red: 0.74, green: 0.46, blue: 0.24)
    static let liftRed = Color(red: 0.92, green: 0.27, blue: 0.38)
}

struct AppBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.liftBackground
                .ignoresSafeArea()
            content
        }
        .foregroundStyle(.white)
    }
}

struct LiftCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var symbolName = "chart.bar.fill"
    var tint = Color.liftBlue

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbolName)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                }
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)
            }
        }
    }
}

struct ProfileAvatar: View {
    let profile: UserProfile
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.liftBlue.opacity(0.16))
            Image(systemName: profile.profileImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.liftBlue)
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(profile.displayName) profile photo")
    }
}

struct VerificationBadge: View {
    let status: VerificationStatus

    var color: Color {
        switch status {
        case .selfReported: return Color.liftMuted
        case .videoSubmitted: return Color.liftBlue
        case .communityVerified: return Color.cyan
        case .moderatorVerified: return Color.liftGreen
        case .competitionVerified: return Color.liftGold
        case .rejected: return Color.liftRed
        }
    }

    var body: some View {
        Label(status.rawValue, systemImage: status == .rejected ? "xmark.seal.fill" : "checkmark.seal.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel("Verification status: \(status.rawValue)")
    }
}

struct FilterChip: View {
    let title: String
    var isActive = true
    var action: (() -> Void)?

    var body: some View {
        Button {
            Haptics.light()
            action?()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if action != nil {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isActive ? Color.liftBlue.opacity(0.18) : Color.liftCard)
            .foregroundStyle(isActive ? Color.liftBlue : Color.liftMuted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

enum LiftTimeFormatter {
    static func relativeNoSeconds(from date: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Just now" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }

        let days = hours / 24
        if days < 7 { return "\(days)d ago" }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func messageTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct PrimaryButton: View {
    let title: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [Color.liftBlue, Color(red: 0.08, green: 0.50, blue: 0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .foregroundStyle(Color.liftBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .frame(height: 5)
                        .padding(.horizontal, 2)
                }
        }
        .buttonStyle(.plain)
    }
}

enum NumericInputPresentation {
    case card
    case inset
    case formRow

    var background: Color {
        switch self {
        case .card:
            return Color.liftCard
        case .inset, .formRow:
            return Color.black.opacity(0.18)
        }
    }

    var padding: CGFloat {
        switch self {
        case .card:
            return 16
        case .inset:
            return 12
        case .formRow:
            return 0
        }
    }
}

struct NumericInputField: View {
    let title: String
    @Binding var value: Double
    var unit: String?
    var precision: ClosedRange<Int> = 0...1
    var presentation: NumericInputPresentation = .card

    var body: some View {
        switch presentation {
        case .formRow:
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: $value, format: .number.precision(.fractionLength(precision)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let unit {
                    Text(unit)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        case .card, .inset:
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    TextField(title, value: $value, format: .number.precision(.fractionLength(precision)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .padding(presentation.padding)
                .background(presentation.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct IntegerInputField: View {
    let title: String
    @Binding var value: Int
    var unit: String?
    var presentation: NumericInputPresentation = .card

    var body: some View {
        switch presentation {
        case .formRow:
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let unit {
                    Text(unit)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        case .card, .inset:
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    TextField(title, value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .padding(presentation.padding)
                .background(presentation.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct OptionalNumericInputField: View {
    let title: String
    @Binding var value: Double?
    var unit: String?
    var presentation: NumericInputPresentation = .inset
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Double?>, unit: String? = nil, presentation: NumericInputPresentation = .inset) {
        self.title = title
        self._value = value
        self.unit = unit
        self.presentation = presentation
        self._text = State(initialValue: value.wrappedValue.map(Self.format) ?? "")
    }

    var body: some View {
        optionalField(keyboard: .decimalPad)
            .onChange(of: text) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value = trimmed.isEmpty ? nil : Double(trimmed)
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    text = newValue.map(Self.format) ?? ""
                }
            }
    }

    private func optionalField(keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Optional", text: $text)
                    .focused($isFocused)
                    .keyboardType(keyboard)
                    .textFieldStyle(.plain)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(presentation.padding == 0 ? 10 : presentation.padding)
            .background(presentation == .formRow ? Color.clear : presentation.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct OptionalIntegerInputField: View {
    let title: String
    @Binding var value: Int?
    var unit: String?
    var presentation: NumericInputPresentation = .inset
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Int?>, unit: String? = nil, presentation: NumericInputPresentation = .inset) {
        self.title = title
        self._value = value
        self.unit = unit
        self.presentation = presentation
        self._text = State(initialValue: value.wrappedValue.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Optional", text: $text)
                    .focused($isFocused)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(presentation.padding == 0 ? 10 : presentation.padding)
            .background(presentation == .formRow ? Color.clear : presentation.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onChange(of: text) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            value = trimmed.isEmpty ? nil : Int(trimmed)
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                text = newValue.map(String.init) ?? ""
            }
        }
    }
}
