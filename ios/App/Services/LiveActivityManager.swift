import Foundation
import ActivityKit

/// 管理灵动岛 / 锁屏实时活动（Live Activity）。
/// 说明：这里只做"本机内更新"（App 前台/后台被系统唤醒定位时调用 update），
/// 没有接入远程推送（APNs）更新通道，因为远程推送通常需要付费开发者账号 + 服务器持有 APNs 私钥，
/// 超出免费账号的能力范围。对于"行程进行中"这种场景，App 在收到系统的后台定位回调时
/// 就会被唤醒，此时更新 Live Activity 内容通常已经足够及时。
@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<TripActivityAttributes>?

    func startActivity(routeName: String, direction: String, alightStopName: String, distanceMeters: Double, etaSeconds: TimeInterval?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TripActivityAttributes(routeName: routeName, direction: direction, alightStopName: alightStopName)
        let state = TripActivityAttributes.ContentState(
            distanceMeters: distanceMeters,
            etaSeconds: etaSeconds,
            stageDescription: NSLocalizedString("live_activity.in_progress", comment: "")
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            currentActivity = activity
        } catch {
            #if DEBUG
            print("启动 Live Activity 失败: \(error)")
            #endif
        }
    }

    func update(distanceMeters: Double, etaSeconds: TimeInterval?, stageDescription: String) {
        guard let activity = currentActivity else { return }
        let state = TripActivityAttributes.ContentState(
            distanceMeters: distanceMeters,
            etaSeconds: etaSeconds,
            stageDescription: stageDescription
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
