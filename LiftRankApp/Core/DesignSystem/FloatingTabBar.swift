import SwiftUI

struct FloatingTabItem: Identifiable {
    var id: String { tab.map { String(describing: $0) } ?? "utility-\(title)" }
    let tab: AppTab?
    let icon: String
    let title: String
    let isUtility: Bool
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let items: [FloatingTabItem]
    var utilityAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                if item.isUtility {
                    Spacer()
                    Button {
                        Haptics.light()
                        utilityAction?()
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.liftOnAccent)
                            .frame(width: 48, height: 48)
                            .background(Color.liftLime)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    Spacer()
                } else {
                    Button {
                        Haptics.light()
                        withAnimation(LiftMotion.quick) {
                            if let tab = item.tab {
                                selection = tab
                            }
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(item.tab == selection ? Color.liftLime : Color.liftTextSecondary)
                            Text(item.title)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.3)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .allowsTightening(true)
                                .foregroundStyle(item.tab == selection ? Color.liftLime : Color.liftTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityIdentifier("mainTab.\(item.tab.map { String(describing: $0) } ?? "unknown")")
                    .accessibilityValue(item.tab == selection ? "selected" : "not selected")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.liftSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.liftSurfaceBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}
