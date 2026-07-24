import SwiftUI

struct ForumReportDraft: Identifiable {
    let id: UUID
    let type: ForumReportTargetType
    let title: String
}

struct ForumReportSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let target: ForumReportDraft
    let communityID: UUID?
    @State private var reason: CommunityReportReason = .spam
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(target.title).font(.subheadline.weight(.semibold))
                    Picker("Reason", selection: $reason) {
                        ForEach(CommunityReportReason.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Optional details", text: $note, axis: .vertical).lineLimit(3...6)
                } header: {
                    Text("Report \(target.type.rawValue.lowercased())")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.liftBackground)
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        if appState.reportForumContent(
                            targetType: target.type,
                            targetID: target.id,
                            communityID: communityID,
                            reason: reason,
                            note: note
                        ) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct ForumEditPostView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let post: ForumPost
    @State private var title: String
    @State private var bodyText: String

    init(post: ForumPost) {
        self.post = post
        _title = State(initialValue: post.title)
        _bodyText = State(initialValue: post.body)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("5–140 characters", text: $title)
                    Text("\(title.count)/140").font(.caption).foregroundStyle(Color.liftMuted)
                }
                Section("Body") {
                    TextEditor(text: $bodyText).frame(minHeight: 160)
                    Text("\(bodyText.count)/10,000").font(.caption).foregroundStyle(Color.liftMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.liftBackground)
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.updateForumPost(post, title: title, body: bodyText)
                        dismiss()
                    }
                    .disabled(
                        !(5...140).contains(title.trimmingCharacters(in: .whitespacesAndNewlines).count) ||
                        bodyText.count > 10_000
                    )
                }
            }
        }
    }
}

struct ForumCommunityEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var summary = ""
    @State private var details = ""
    @State private var category = "Training"
    @State private var visibility: ForumCommunityVisibility = .publicOpen
    @State private var rules = ["Be constructive", "No spam"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Community name", text: $name)
                    TextField("Short summary", text: $summary)
                    TextField("Full description", text: $details, axis: .vertical).lineLimit(3...7)
                    TextField("Category", text: $category)
                }
                Section("Access") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(ForumCommunityVisibility.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Rules") {
                    ForEach(rules.indices, id: \.self) { index in
                        TextField("Rule \(index + 1)", text: $rules[index])
                    }
                    Button("Add Rule") {
                        if rules.count < 10 { rules.append("") }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.liftBackground)
            .navigationTitle("New Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if appState.createForumCommunity(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                            visibility: visibility,
                            rules: rules.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        ) {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || summary.isEmpty)
                }
            }
        }
    }
}
