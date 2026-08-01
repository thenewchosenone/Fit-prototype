import SwiftUI

struct LiftPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .black, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .padding(.horizontal, 16)
            .foregroundStyle(isEnabled ? Color.liftOnAccent : Color.liftMuted)
            .background(isEnabled ? Color.liftLime.opacity(configuration.isPressed ? 0.82 : 1) : Color.liftSurfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isEnabled ? Color.clear : Color.liftSurfaceBorder, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(LiftMotion.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(minHeight: LiftDesign.minimumTouchTarget)
            .padding(.horizontal, 14)
            .foregroundStyle(isEnabled ? Color.liftLime : Color.liftTextDisabled)
            .background(Color.liftCard.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous)
                    .stroke(Color.liftSurfaceBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct LiftCompactProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .foregroundStyle(isEnabled ? Color.liftOnAccent : Color.liftTextDisabled)
            .background(isEnabled ? Color.liftLime.opacity(configuration.isPressed ? 0.82 : 1) : Color.liftLime.opacity(0.35))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(LiftMotion.quick, value: configuration.isPressed)
    }
}

typealias LiftSecondaryButtonStyle = SecondaryButtonStyle

struct SecondaryButton: View {
    let title: String
    let symbolName: String?
    let action: () -> Void

    init(_ title: String, symbolName: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbolName = symbolName
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            if let symbolName {
                Label(title, systemImage: symbolName)
            } else {
                Text(title)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}

struct PrimaryButton: View {
    let title: String
    let symbolName: String
    let action: () -> Void

    init(title: String, symbolName: String = "", action: @escaping () -> Void) {
        self.title = title
        self.symbolName = symbolName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if symbolName.isEmpty {
                Text(title)
            } else {
                Label(title, systemImage: symbolName)
            }
        }
        .buttonStyle(LiftPrimaryButtonStyle())
    }
}

struct ChoiceChip: View {
    let title: String
    var isActive: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(isActive ? Color.liftOnAccent : Color.liftTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? Color.liftLime : Color.liftCard)
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.liftLime.opacity(0.5) : Color.liftSurfaceBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityValue(isActive ? "selected" : "unselected")
    }
}

struct NativeIconButton: View {
    let symbolName: String
    let accessibilityLabel: String
    var badge: Int? = nil
    var tint = Color.liftText
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: LiftDesign.minimumTouchTarget, height: LiftDesign.minimumTouchTarget)
                    .background(Color.liftCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.liftSurfaceBorder, lineWidth: 1))

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liftOnAccent)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Color.liftRed)
                        .clipShape(Circle())
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct LiftActionRow: View {
    let title: String
    var subtitle: String?
    var symbolName: String
    var tint = Color.liftLime
    var trailingText: String?
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.liftTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.liftTextSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftTextSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftTextSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SegmentedControl: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        selection = option
                    }
                    Haptics.light()
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == option ? Color.liftLime : Color.liftTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(selection == option ? Color.liftLime.opacity(0.14) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selection == option ? Color.liftLime.opacity(0.5) : Color.liftSurfaceBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.liftCard)
        .clipShape(Capsule())
    }
}

struct ProgressBar: View {
    let progress: Double
    var tint: Color = .liftLime

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.liftCard)
                    .frame(height: 8)
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * max(0, min(1, progress)), height: 8)
            }
            .animation(LiftMotion.quick, value: progress)
        }
        .frame(height: 8)
        .accessibilityLabel("Progress \(Int(progress * 100)) percent")
    }
}

struct RingMetric: View {
    let title: String
    let value: String
    let detail: String
    var progress: Double
    var tint: Color = .liftLime

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.liftSurfaceBorder, lineWidth: 10)
                    .frame(width: 124, height: 124)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 124, height: 124)
                    .animation(LiftMotion.spring, value: progress)

                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liftTextPrimary)
                        .monospacedDigit()
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(Color.liftTextSecondary)
                }
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.liftTextSecondary)
        }
    }
}

struct BottomSheet<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.liftSurfaceBorder)
                .frame(width: 34, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liftTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)

            content
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.liftSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.liftSurfaceBorder, lineWidth: 1)
                )
        )
        .animation(reduceMotion ? .linear(duration: 0.01) : LiftMotion.spring, value: title)
    }
}
