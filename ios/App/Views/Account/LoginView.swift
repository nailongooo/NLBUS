import SwiftUI

/// 整个 App 默认"不登录也能完整使用"。这个页面完全可选：
/// 只有当你想以固定昵称提交公开路线、或者未来想跨设备同步收藏时，才需要登录/注册。
struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("logged_in_nickname") private var loggedInNickname: String = ""

    @State private var isRegisterMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(NSLocalizedString("login.optional_hint", comment: ""))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    TextField(NSLocalizedString("login.email", comment: ""), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField(NSLocalizedString("login.password", comment: ""), text: $password)
                    if isRegisterMode {
                        TextField(NSLocalizedString("login.nickname", comment: ""), text: $nickname)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading { ProgressView() } else {
                            Text(isRegisterMode ? NSLocalizedString("login.register_action", comment: "") : NSLocalizedString("login.login_action", comment: ""))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Button(isRegisterMode ? NSLocalizedString("login.switch_to_login", comment: "") : NSLocalizedString("login.switch_to_register", comment: "")) {
                        isRegisterMode.toggle()
                    }
                }
            }
            .navigationTitle(isRegisterMode ? NSLocalizedString("login.register_title", comment: "") : NSLocalizedString("login.login_title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let account: UserAccount
            if isRegisterMode {
                account = try await APIClient.shared.register(email: email, password: password, nickname: nickname)
            } else {
                account = try await APIClient.shared.login(email: email, password: password)
            }
            UserDefaults.standard.set(account.token, forKey: "auth_token")
            loggedInNickname = account.nickname
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
