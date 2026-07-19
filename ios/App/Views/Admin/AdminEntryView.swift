import SwiftUI

struct AdminEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loginSucceeded = false

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("admin.login_hint", comment: "")) {
                    TextField(NSLocalizedString("admin.username", comment: ""), text: $username)
                        .textInputAutocapitalization(.never)
                    SecureField(NSLocalizedString("admin.password", comment: ""), text: $password)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading { ProgressView() } else { Text(NSLocalizedString("admin.login_action", comment: "")).frame(maxWidth: .infinity) }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("admin.entry_title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
            }
            .navigationDestination(isPresented: $loginSucceeded) {
                AdminDashboardView()
            }
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await AdminAPIClient.shared.login(username: username, password: password)
            loginSucceeded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
