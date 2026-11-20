import SwiftUI

struct FloatingTabItem: Identifiable {
    var id: String { String(describing: tab) }
    let tab: AppTab
    let icon: String
    let title: String
}

struct FloatingTabBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: AppTab
    let items: [FloatingTabItem]

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                let current = items.first(where: { $0.tab == selection }) ?? items[0]
                Menu {
                    ForEach(items) { item in
                        Button {
                            Haptics.light()
                            selection = item.tab
                        } label: {
                            Label(item.title, systemImage: item.tab == selection ? "checkmark" : item.icon)
                        }
                        .accessibilityIdentifier("mainTab.menu.\(String(describing: item.tab))")
                        .accessibilityAddTraits(item.tab == selection ? .isSelected : [])
                        .accessibilityValue(item.tab == selection ? "selected" : "not selected")
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: current.icon)
                        Text(current.title)
                            .font(.headline.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.liftAccentText)
                    .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Navigate tabs")
                .accessibilityValue("Current tab: \(current.title)")
                .accessibilityIdentifier("mainTab.menu")
            } else {
                HStack(spacing: 0) {
                    ForEach(items) { tabButton($0) }
                }
            }
        }
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

    private func tabButton(_ item: FloatingTabItem) -> some View {
        let selectedTint = Color.liftAccentText
        return Button {
            Haptics.light()
            selection = item.tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(item.tab == selection ? selectedTint : Color.liftTextSecondary)
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(item.tab == selection ? selectedTint : Color.liftTextSecondary)
            }
            .frame(minWidth: LiftDesign.minimumTouchTarget, maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityIdentifier("mainTab.\(String(describing: item.tab))")
        .accessibilityAddTraits(item.tab == selection ? .isSelected : [])
        .accessibilityValue(item.tab == selection ? "selected" : "not selected")
        .accessibilityShowsLargeContentViewer {
            Label(item.title, systemImage: item.icon)
        }
    }
}
