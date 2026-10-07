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
            .foregroundStyle(isEnabled ? Color.liftAccentText : Color.liftTextDisabled)
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
    var catalogExercise: TrainingExerciseCatalogItem? = nil
    var tint = Color.liftLime
    var trailingText: String?
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let catalogExercise {
                        ExerciseCatalogIcon(exercise: catalogExercise)
                            .scaleEffect(0.63)
                    } else {
                        Image(systemName: symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }
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
