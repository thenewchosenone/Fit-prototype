import SwiftUI

struct FloatingTabItem: Identifiable {
    var id: String { String(describing: tab) }
    let tab: AppTab
    let icon: String
    let title: String
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let items: [FloatingTabItem]

    var body: some View {
        navigationGroup(items)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.liftSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.liftSurfaceBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }

    private func navigationGroup(_ items: [FloatingTabItem]) -> some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    Haptics.light()
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.tab == selection ? Color.liftAccentText : Color.liftTextSecondary)
                        Text(item.title)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                            .foregroundStyle(item.tab == selection ? Color.liftAccentText : Color.liftTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityIdentifier("mainTab.\(String(describing: item.tab))")
                .accessibilityValue(item.tab == selection ? "selected" : "not selected")
            }
        }
    }
}
