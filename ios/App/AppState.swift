import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import Combine

/// 行程当前所处的宏观状态（区别于 TripMonitor 里更细的到站阶段）
enum TripPhase: Equatable {
    case notStarted
    case waitingForBoarding   // 用户选好了路线和上车站，等车中
    case active               // 已经点击"开始行程"，正在监控到站
    case finished
}

/// App 级别的全局状态容器：串联 LocationManager -> TripMonitor -> NotificationManager -> LiveActivityManager，
/// 并负责把"行程历史"写入 SwiftData（只保存在本机）。
@MainActor
final class AppState: ObservableObject {

    let locationManager = LocationManager()
    let tripMonitor = TripMonitor()
    let notificationManager = NotificationManager.shared

    @Published var tripPhase: TripPhase = .notStarted
    @Published var activeRoute: Route?
    @Published var boardStop: Stop?
    @Published var alightStop: Stop?
    @Published var currentTripRecord: Trip?

    // 设置项，全部本地存储（AppStorage 也可以，这里为了能在类里统一管理用 @Published + UserDefaults 手动同步）
    @Published var preferredColorSchemeRaw: String {
        didSet { UserDefaults.standard.set(preferredColorSchemeRaw, forKey: "pref_color_scheme") }
    }
    @Published var accentColorHex: String {
        didSet { UserDefaults.standard.set(accentColorHex, forKey: "pref_accent_color") }
    }
    @Published var reminderDistanceOverrideEnabled: Bool {
        didSet { UserDefaults.standard.set(reminderDistanceOverrideEnabled, forKey: "pref_reminder_override_enabled") }
    }
    @Published var overridePreAlertMeters: Double {
        didSet { UserDefaults.standard.set(overridePreAlertMeters, forKey: "pref_pre_alert_meters") }
    }
    @Published var overrideApproachingMeters: Double {
        didSet { UserDefaults.standard.set(overrideApproachingMeters, forKey: "pref_approaching_meters") }
    }
    @Published var overrideArrivalMeters: Double {
        didSet { UserDefaults.standard.set(overrideArrivalMeters, forKey: "pref_arrival_meters") }
    }

    var modelContext: ModelContext?

    init() {
        let defaults = UserDefaults.standard
        preferredColorSchemeRaw = defaults.string(forKey: "pref_color_scheme") ?? "system"
        accentColorHex = defaults.string(forKey: "pref_accent_color") ?? "#3A7DFF"
        reminderDistanceOverrideEnabled = defaults.bool(forKey: "pref_reminder_override_enabled")
        overridePreAlertMeters = defaults.object(forKey: "pref_pre_alert_meters") as? Double ?? 1500
        overrideApproachingMeters = defaults.object(forKey: "pref_approaching_meters") as? Double ?? 500
        overrideArrivalMeters = defaults.object(forKey: "pref_arrival_meters") as? Double ?? 150

        locationManager.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.handleLocationUpdate(location)
            }
        }
        tripMonitor.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleTripEvent(event)
            }
        }
    }

    // MARK: - 行程生命周期

    func selectRoute(_ route: Route, board: Stop, alight: Stop) {
        activeRoute = route
        boardStop = board
        alightStop = alight
        tripPhase = .waitingForBoarding
        locationManager.requestWhenInUseAuthorization()
        locationManager.startForegroundOnlyUpdates()
    }

    /// 对应产品需求：不做全自动上车识别，用户手动点击"开始行程"，系统只是辅助判断。
    func beginTrip() {
        guard let route = activeRoute, let alight = alightStop else { return }
        locationManager.requestAlwaysAuthorizationIfNeeded()
        locationManager.startTripTracking()

        var effectiveRoute = route
        if reminderDistanceOverrideEnabled {
            effectiveRoute.preAlertMeters = overridePreAlertMeters
            effectiveRoute.approachingMeters = overrideApproachingMeters
            effectiveRoute.arrivalMeters = overrideArrivalMeters
        }
        tripMonitor.beginMonitoring(route: effectiveRoute, alightStop: alight)
        tripPhase = .active

        let trip = Trip(
            routeId: route.id,
            routeName: route.name,
            direction: route.direction,
            boardStopName: boardStop?.name ?? "",
            boardStopOrder: boardStop?.order ?? 0,
            alightStopName: alight.name,
            alightStopOrder: alight.order,
            startedAt: Date()
        )
        currentTripRecord = trip
        modelContext?.insert(trip)

        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.startActivity(
                routeName: route.name,
                direction: route.direction,
                alightStopName: alight.name,
                distanceMeters: 0,
                etaSeconds: nil
            )
        }
    }

    func endTrip(manually: Bool) {
        locationManager.stopTripTracking()
        currentTripRecord?.endedAt = Date()
        currentTripRecord?.distanceMeters = tripMonitor.accumulatedDistanceMeters
        try? modelContext?.save()

        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.end()
        }

        tripMonitor.reset()
        tripPhase = .finished
        activeRoute = nil
        boardStop = nil
        alightStop = nil
        currentTripRecord = nil
    }

    func cancelWaiting() {
        locationManager.stopForegroundOnlyUpdates()
        tripPhase = .notStarted
        activeRoute = nil
        boardStop = nil
        alightStop = nil
    }

    // MARK: - 内部回调

    private func handleLocationUpdate(_ location: CLLocation) {
        switch tripPhase {
        case .active:
            tripMonitor.processLocation(location)
            reportCrowdsourcedPingIfNeeded(location)
        case .waitingForBoarding:
            checkBoardingReminder(location)
        default:
            break
        }
    }

    private func handleTripEvent(_ event: TripEvent) {
        guard let route = activeRoute, let alight = alightStop else { return }
        switch event {
        case .stageChanged(let stage, let distance):
            notificationManager.sendStageNotification(stage: stage, routeName: route.name, alightStopName: alight.name, distanceMeters: distance)
            if #available(iOS 16.1, *) {
                LiveActivityManager.shared.update(distanceMeters: distance, etaSeconds: tripMonitor.latestETA?.etaSeconds, stageDescription: stageDescription(stage))
            }
        case .missedStopSuspected:
            notificationManager.sendMissedStopAlert(routeName: route.name, alightStopName: alight.name)
            currentTripRecord?.missedStopTriggered = true
        case .boardingReminder(let message):
            notificationManager.sendBoardingReminder(message: message)
        case .gpsWeak:
            break
        case .etaUpdated(let estimate):
            if #available(iOS 16.1, *) {
                LiveActivityManager.shared.update(distanceMeters: tripMonitor.distanceToAlightMeters ?? 0, etaSeconds: estimate.etaSeconds, stageDescription: stageDescription(tripMonitor.currentStage))
            }
        }
    }

    private func stageDescription(_ stage: ArrivalStage) -> String {
        switch stage {
        case .idle: return NSLocalizedString("stage.idle", comment: "")
        case .preAlert: return NSLocalizedString("stage.pre_alert", comment: "")
        case .approaching: return NSLocalizedString("stage.approaching", comment: "")
        case .arrival: return NSLocalizedString("stage.arrival", comment: "")
        }
    }

    /// 行程进行中，把匿名位置作为"众包车辆位置"上报给服务器，供同一路线上的其它乘客参考。
    private var lastPingSentAt: Date?
    private func reportCrowdsourcedPingIfNeeded(_ location: CLLocation) {
        guard let route = activeRoute else { return }
        let now = Date()
        if let last = lastPingSentAt, now.timeIntervalSince(last) < 15 { return } // 最多每 15 秒上报一次
        lastPingSentAt = now
        let ping = APIClient.TripPing(
            routeId: route.id,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedKmh: max(location.speed, 0) * 3.6,
            headingDegrees: location.course >= 0 ? location.course : 0
        )
        Task {
            try? await APIClient.shared.sendTripPing(ping)
        }
    }

    /// 等车阶段的"上车提醒"：优先用众包实时车辆位置估算 ETA，没有数据时退化为提示发车间隔。
    private var lastBoardingCheckAt: Date?
    private var boardingReminderSent = false
    private func checkBoardingReminder(_ location: CLLocation) {
        guard let route = activeRoute, let board = boardStop, !boardingReminderSent else { return }
        let now = Date()
        if let last = lastBoardingCheckAt, now.timeIntervalSince(last) < 20 { return }
        lastBoardingCheckAt = now

        Task {
            if let vehicles = try? await APIClient.shared.fetchLiveVehicles(routeId: route.id), !vehicles.isEmpty {
                let nearest = vehicles.min { a, b in
                    let da = CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: board.location)
                    let db = CLLocation(latitude: b.latitude, longitude: b.longitude).distance(from: board.location)
                    return da < db
                }
                if let nearest, let speed = nearest.speedKmh, speed > 1 {
                    let distance = CLLocation(latitude: nearest.latitude, longitude: nearest.longitude).distance(from: board.location)
                    let etaMinutes = (distance / (speed * 1000 / 3600)) / 60
                    if etaMinutes <= 3 {
                        boardingReminderSent = true
                        tripMonitor.onEvent?(.boardingReminder(message: String(format: NSLocalizedString("notif.boarding.eta_body", comment: ""), Int(etaMinutes) + 1)))
                    }
                }
            } else if let headway = route.headwayMinutes {
                // 没有众包数据，退化为提示大概的发车间隔，明确告知这不是实时数据
                boardingReminderSent = true
                tripMonitor.onEvent?(.boardingReminder(message: String(format: NSLocalizedString("notif.boarding.headway_body", comment: ""), headway)))
            }
        }
    }
}
