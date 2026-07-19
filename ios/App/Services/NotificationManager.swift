import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox
import UIKit

/// 统一管理"到站提醒"的多种提醒方式：
/// - 系统通知（含锁屏、时效性通知）
/// - 声音 + 震动
/// - App 在前台时的持续响铃（用户手动停止）
/// - App 内弹窗
///
/// 重要说明（诚实告知能力边界）：
/// iOS 出于系统资源和用户体验保护，不允许普通 App 在后台"无限期持续响铃"，
/// 这项能力仅对拿到 Apple 特批的"Critical Alerts"权限的 App 开放（审批门槛较高，
/// 个人开发者一般申请不到）。因此：
/// - App 在前台时：使用 AVAudioPlayer 循环播放，直到用户点击"停止"按钮，体验等同于闹钟。
/// - App 在后台/锁屏时：连续发送几条间隔几秒的本地通知（模拟连续提醒），
///   属于业界常见的折中方案。
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    @Published var isForegroundAlertRinging = false
    @Published var foregroundAlertTitle: String = ""
    @Published var foregroundAlertMessage: String = ""

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            #if DEBUG
            print("通知权限：\(granted)")
            #endif
        }
    }

    // MARK: - 三段式到站提醒

    func sendStageNotification(stage: ArrivalStage, routeName: String, alightStopName: String, distanceMeters: Double) {
        let title: String
        let body: String
        let interruptionLevel: UNNotificationInterruptionLevel

        switch stage {
        case .preAlert:
            title = NSLocalizedString("notif.pre_alert.title", comment: "")
            body = String(format: NSLocalizedString("notif.pre_alert.body", comment: ""), alightStopName)
            interruptionLevel = .active
        case .approaching:
            title = NSLocalizedString("notif.approaching.title", comment: "")
            body = String(format: NSLocalizedString("notif.approaching.body", comment: ""), alightStopName)
            interruptionLevel = .timeSensitive
        case .arrival:
            title = NSLocalizedString("notif.arrival.title", comment: "")
            body = String(format: NSLocalizedString("notif.arrival.body", comment: ""), alightStopName)
            interruptionLevel = .timeSensitive
        case .idle:
            return
        }

        postLocalNotification(title: title, body: body, interruptionLevel: interruptionLevel, soundName: "default")

        if stage == .arrival {
            // 触发"持续响铃直到用户停止"体验；如果此时 App 恰好在前台，会展示全屏弹窗+循环声音。
            triggerForegroundRingIfActive(title: title, message: body)
            scheduleBackgroundReminderBurst(title: title, body: body)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func sendBoardingReminder(message: String) {
        postLocalNotification(
            title: NSLocalizedString("notif.boarding.title", comment: ""),
            body: message,
            interruptionLevel: .timeSensitive,
            soundName: "default"
        )
    }

    func sendMissedStopAlert(routeName: String, alightStopName: String) {
        let title = NSLocalizedString("notif.missed_stop.title", comment: "")
        let body = String(format: NSLocalizedString("notif.missed_stop.body", comment: ""), alightStopName)
        postLocalNotification(title: title, body: body, interruptionLevel: .timeSensitive, soundName: "default")
        triggerForegroundRingIfActive(title: title, message: body)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: - 底层实现

    private func postLocalNotification(title: String, body: String, interruptionLevel: UNNotificationInterruptionLevel, soundName: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = interruptionLevel
            if interruptionLevel == .timeSensitive {
                content.relevanceScore = 1.0
            }
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    /// 给到站提醒配一个"连续几条"的补充通知，弥补系统不允许无限响铃的限制。
    private func scheduleBackgroundReminderBurst(title: String, body: String) {
        for i in 1...3 {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(i) * 8, repeats: false)
            let request = UNNotificationRequest(identifier: "burst-\(UUID().uuidString)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func triggerForegroundRingIfActive(title: String, message: String) {
        guard UIApplication.shared.applicationState == .active else { return }
        foregroundAlertTitle = title
        foregroundAlertMessage = message
        isForegroundAlertRinging = true
        playLoopingSound()
    }

    func stopForegroundRing() {
        isForegroundAlertRinging = false
        ringTimer?.invalidate()
        ringTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private var ringTimer: Timer?

    /// 用系统内建提示音（AudioServicesPlaySystemSound）按固定间隔重复播放，
    /// 实现"持续响铃直到用户点击停止"的效果，不需要额外打包任何音频资源文件，
    /// 从而避免因为资源缺失导致 Xcode 打包失败。
    private func playLoopingSound() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // 1005 是系统内建的提示音 ID（新邮件提示音），任何 iOS 版本都自带，无需额外资源。
        let systemSoundID: SystemSoundID = 1005
        AudioServicesPlaySystemSound(systemSoundID)
        ringTimer?.invalidate()
        ringTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }

    // 前台收到通知时也展示系统横幅，方便用户即使正盯着别的页面也能看到
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
