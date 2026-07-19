import SwiftUI

struct ProfileView: View {
    @AppStorage("logged_in_nickname") private var loggedInNickname: String = ""
    @State private var showingLogin = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        if loggedInNickname.isEmpty {
                            Text(NSLocalizedString("profile.guest", comment: "")).font(.headline)
                            Text(NSLocalizedString("profile.guest_hint", comment: "")).font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text(loggedInNickname).font(.headline)
                            Text(NSLocalizedString("profile.logged_in_hint", comment: "")).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if loggedInNickname.isEmpty {
                        Button(NSLocalizedString("profile.login_button", comment: "")) { showingLogin = true }
                    } else {
                        Button(NSLocalizedString("profile.logout_button", comment: "")) {
                            UserDefaults.standard.removeObject(forKey: "auth_token")
                            loggedInNickname = ""
                        }
                        .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                NavigationLink(NSLocalizedString("nav.history", comment: "")) { TripHistoryView() }
                NavigationLink(NSLocalizedString("nav.settings", comment: "")) { SettingsView() }
                NavigationLink(NSLocalizedString("nav.feedback", comment: "")) { FeedbackView() }
                NavigationLink(NSLocalizedString("nav.about", comment: "")) { AboutView() }
            }
        }
        .navigationTitle(NSLocalizedString("tab.profile", comment: ""))
        .sheet(isPresented: $showingLogin) { LoginView() }
    }
}
