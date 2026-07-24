import SwiftUI

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
        .foregroundStyle(Color.liftTextPrimary)
        .tint(Color.liftLime)
    }
}

struct LiftCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LiftDesign.cardRadius, style: .continuous)
                    .stroke(Color.liftSurfaceBorder, lineWidth: 1)
            }
    }
}

struct ProfileAvatar: View {
    @EnvironmentObject private var appState: AppState
    let profile: UserProfile
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let image = LocalProfilePhotoStore.shared.thumbnail(for: profile.avatarPath) ??
                LocalProfilePhotoStore.shared.image(for: profile.avatarPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.liftLime.opacity(0.16))
                Image(systemName: profile.profileImageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.liftLime)
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(profile.displayName) profile photo")
    }
}

struct VerificationBadge: View {
    let evidenceStatus: LiftEvidenceStatus
    let compact: Bool

    init(evidenceStatus: LiftEvidenceStatus, compact: Bool = false) {
        self.evidenceStatus = evidenceStatus
        self.compact = compact
    }
    init(status: VerificationStatus) {
        self.evidenceStatus = status == .selfReported ? .selfReported : .videoBacked
        self.compact = false
    }
    init(status: VerificationStatus, compact: Bool) {
        self.evidenceStatus = status == .selfReported ? .selfReported : .videoBacked
        self.compact = compact
    }

    private var compactSymbol: String {
        evidenceStatus.evidenceMetricSymbol
    }

    private var compactLabel: String {
        evidenceStatus.displayName
    }

    private var compactTint: Color {
        evidenceStatus.evidenceMetricTint
    }

    var color: Color {
        evidenceStatus.evidenceMetricTint
    }

    var body: some View {
        Label(
            compactLabel,
            systemImage: compactSymbol
        )
        .font(compact ? .system(size: 10, weight: .bold) : .caption2.weight(.bold))
        .padding(.horizontal, compact ? 8 : 9)
        .padding(.vertical, compact ? 3 : 6)
        .frame(minHeight: compact ? 24 : nil)
        .background(compactTint.opacity(0.13))
        .foregroundStyle(compactTint)
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Evidence: \(compactLabel)")
    }
}

extension LiftEvidenceStatus {
    var evidenceMetricSymbol: String {
        self == .videoBacked ? "video.fill" : "person.fill"
    }

    var evidenceMetricValue: String {
        self == .videoBacked ? "Video-backed" : "Self-reported"
    }

    var evidenceMetricSubtitle: String {
        self == .videoBacked
            ? "Your uploaded video is available from your profile."
            : "This lift is saved, but no playable video is attached."
    }

    var evidenceMetricTint: Color {
        self == .videoBacked ? Color.liftGreen : Color.liftMuted
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
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.4)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.liftLime.opacity(0.16) : Color.liftCard)
            .foregroundStyle(isActive ? Color.liftLime : Color.liftMuted)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.liftSurfaceBorder, lineWidth: 1))
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

    static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func shortMonthAndYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    static func shortDateTime(_ date: Date) -> String {
        date.formatted(date: .complete, time: .shortened)
    }

    static func shortDateNoTime(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }

    static func shortDateCompactTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func relative(_ date: Date, wide: Bool = false) -> String {
        return wide
            ? date.formatted(.relative(presentation: .named))
            : date.formatted(.relative(presentation: .named, unitsStyle: .narrow))
    }
}

struct SectionHeader: View {
    let title: String
    var eyebrow: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Color.liftLime)
                }
                Text(title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.liftTextPrimary)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liftLime)
                    .padding(.horizontal, 12)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                    .background(Color.liftLime.opacity(0.13))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CompactSectionHeader: View {
    let title: String
    var eyebrow: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Color.liftLime)
                }
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liftTextPrimary)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.liftLime)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct ScreenContainer<Content: View>: View {
    let title: String?
    let showTitle: Bool
    let spacing: CGFloat
    let content: Content
    let headerAction: (() -> AnyView)?

    init(
        title: String? = nil,
        showTitle: Bool = false,
        spacing: CGFloat = LiftDesign.spacing20,
        @ViewBuilder headerAction: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showTitle = showTitle
        self.spacing = spacing
        self.content = content()
        self.headerAction = { AnyView(headerAction()) }
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                if showTitle, let title {
                    Text(title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liftTextPrimary)
                        .padding(.horizontal, LiftDesign.screenHorizontalPadding)
                        .padding(.top, LiftDesign.spacing16)
                        .padding(.bottom, LiftDesign.spacing12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let headerAction {
                    headerAction()
                        .padding(.horizontal, LiftDesign.screenHorizontalPadding)
                        .padding(.bottom, spacing)
                }

                content
                    .padding(.horizontal, LiftDesign.screenHorizontalPadding)
            }
        }
    }
}

struct DashboardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LiftDesign.cardRadius, style: .continuous)
                    .stroke(Color.liftSurfaceBorder, lineWidth: 1)
            }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var symbolName = "chart.bar.fill"
    var tint = Color.liftLime

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbolName)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(Color.liftTextSecondary)
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.liftTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.liftTextSecondary)
                    .lineLimit(2)
            }
        }
    }
}

struct LiftEmptyState: View {
    let title: String
    let message: String
    var symbolName = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.liftLime)
                .frame(width: 48, height: 48)
                .background(Color.liftLime.opacity(0.14))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.liftTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.liftLime)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: LiftDesign.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LiftDesign.cardRadius, style: .continuous)
                .stroke(Color.liftSurfaceBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct LiftSheetHeader: View {
    let title: String
    var subtitle: String?
    var close: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liftTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftTextSecondary)
                }
            }
            Spacer()
            if let close {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(Color.liftTextSecondary)
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.liftSurfaceBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }
}

extension View {
    func liftSurface(
        radius: CGFloat = LiftDesign.cardRadius,
        raised: Bool = false
    ) -> some View {
        modifier(_LiftSurfaceModifier(radius: radius, raised: raised))
    }
}

private struct _LiftSurfaceModifier: ViewModifier {
    let radius: CGFloat
    let raised: Bool

    func body(content: Content) -> some View {
        content
            .background(raised ? Color.liftCardRaised : Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.liftSurfaceBorder, lineWidth: 1)
            }
    }
}
