import SwiftUI

struct AdminAnnouncementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var isPinned = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(NSLocalizedString("admin.announcement.title_section", comment: "")) {
                TextField(NSLocalizedString("admin.announcement.title_placeholder", comment: ""), text: $title)
            }
            Section(NSLocalizedString("admin.announcement.content_section", comment: "")) {
                TextEditor(text: $content).frame(height: 140)
            }
            Toggle(NSLocalizedString("admin.announcement.pin", comment: ""), isOn: $isPinned)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting { ProgressView() } else { Text(NSLocalizedString("common.publish", comment: "")).frame(maxWidth: .infinity) }
                }
                .disabled(title.isEmpty || content.isEmpty || isSubmitting)
            }
        }
        .navigationTitle(NSLocalizedString("admin.announcement_nav", comment: ""))
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await AdminAPIClient.shared.postAnnouncement(title: title, content: content, isPinned: isPinned)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
