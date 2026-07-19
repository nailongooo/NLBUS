import SwiftUI

/// App 处于前台时，"到站提醒/坐过站提醒"触发后展示的全屏样式弹窗，
/// 配合 NotificationManager 的循环响铃，直到用户点击"我知道了"停止。
struct ArrivalBanner: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        if notificationManager.isForegroundAlertRinging {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                GlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                            .symbolEffect(.bounce, options: .repeating)

                        Text(notificationManager.foregroundAlertTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(notificationManager.foregroundAlertMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button {
                            notificationManager.stopForegroundRing()
                        } label: {
                            Text(NSLocalizedString("common.i_know", comment: ""))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: appState.accentColorHex))
                    }
                }
                .padding(32)
            }
            .transition(.opacity)
            .animation(.easeInOut, value: notificationManager.isForegroundAlertRinging)
        }
    }
}
