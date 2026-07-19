import SwiftUI

struct FeedbackView: View {
    @State private var content = ""
    @State private var contact = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(NSLocalizedString("feedback.content_section", comment: "")) {
                TextEditor(text: $content).frame(height: 160)
            }
            Section(NSLocalizedString("feedback.contact_section", comment: "")) {
                TextField(NSLocalizedString("feedback.contact_placeholder", comment: ""), text: $contact)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting { ProgressView() } else { Text(NSLocalizedString("common.submit", comment: "")).frame(maxWidth: .infinity) }
                }
                .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            }
        }
        .navigationTitle(NSLocalizedString("nav.feedback", comment: ""))
        .alert(NSLocalizedString("feedback.thanks_title", comment: ""), isPresented: $submitted) {
            Button(NSLocalizedString("common.ok", comment: "")) { content = ""; contact = "" }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await APIClient.shared.submitFeedback(content: content, contact: contact.isEmpty ? nil : contact)
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
