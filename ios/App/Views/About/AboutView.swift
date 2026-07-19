import SwiftUI

struct AboutView: View {
    @State private var versionTapCount = 0
    @State private var showingAdminEntry = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .padding(.top, 24)

                Text(NSLocalizedString("app.name", comment: "")).font(.title.bold())

                // 隐藏管理员入口：连续点击版本号 7 次进入，避免普通用户误触，
                // 同时不需要单独在主界面放一个显眼的"管理员"按钮。
                Text(String(format: NSLocalizedString("about.version", comment: ""), appVersionString))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            versionTapCount = 0
                            showingAdminEntry = true
                        }
                    }

                Text(NSLocalizedString("about.description", comment: ""))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(NSLocalizedString("about.privacy_note", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .navigationTitle(NSLocalizedString("nav.about", comment: ""))
        .sheet(isPresented: $showingAdminEntry) {
            AdminEntryView()
        }
    }

    private var appVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}
