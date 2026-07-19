import Foundation
import CoreLocation

/// 到站提醒会经历的阶段。每个阶段只触发一次。
enum ArrivalStage: Int, Comparable {
    case idle = 0
    case preAlert       // 距离 <= preAlertMeters（默认 1500 米）
    case approaching    // 距离 <= approachingMeters（默认 500 米）
    case arrival        // 距离 <= arrivalMeters（默认 150 米）

    static func < (lhs: ArrivalStage, rhs: ArrivalStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 行程状态机产生的事件，由上层（NotificationManager / LiveActivityManager / UI）消费
enum TripEvent {
    case stageChanged(ArrivalStage, distanceMeters: Double)
    case boardingReminder(message: String)
    case missedStopSuspected
    case gpsWeak
    case etaUpdated(ETAEstimate)
}

/// 核心业务逻辑：根据连续的定位点，判断"预提醒 / 即将到站 / 到站提醒 / 坐过站"。
///
/// 规则（对应产品需求确认稿）：
/// - 距目标站 1500 米：预提醒（只触发一次）
/// - 距目标站 500 米：即将到站（只触发一次）
/// - 距目标站 150 米：到站提醒（只触发一次）
/// - 连续 2 次有效定位都满足条件才真正触发，避免 GPS 漂移误报
/// - 定位精度差于 65 米时，本次读数不参与阶段判断（既不前进也不后退）
/// - 到站提醒触发后，如果用户距离"下一站"反而更近，或者距目标站的距离相比历史最小值明显变大，
///   判定为"疑似坐过站"
final class TripMonitor: ObservableObject {

    @Published private(set) var currentStage: ArrivalStage = .idle
    @Published private(set) var distanceToAlightMeters: Double?
    @Published private(set) var gpsSignalWeak: Bool = false
    @Published private(set) var latestETA: ETAEstimate?

    var onEvent: ((TripEvent) -> Void)?

    // 可配置的阈值（来自 Route，也允许用户在设置里覆盖）
    private var preAlertMeters: Double = 1500
    private var approachingMeters: Double = 500
    private var arrivalMeters: Double = 150
    private var averageSpeedKmh: Double = 20

    private let accuracyThreshold: CLLocationAccuracy = 65
    private let requiredConsecutiveReadings = 2

    private var alightStop: Stop?
    private var stopAfterAlight: Stop?
    private var route: Route?

    // 状态追踪
    private var consecutiveQualifyingReadings: [ArrivalStage: Int] = [:]
    private var minDistanceRecorded: Double = .greatestFiniteMagnitude
    private var arrivalStageTriggeredAt: Date?
    private var missedStopAlreadyTriggered = false

    /// 用户实际累计移动距离（用于行程历史统计）
    private(set) var accumulatedDistanceMeters: Double = 0
    private var lastLocationForDistance: CLLocation?

    func beginMonitoring(route: Route, alightStop: Stop) {
        self.route = route
        self.alightStop = alightStop
        self.stopAfterAlight = route.stops.first(where: { $0.order == alightStop.order + 1 })
        self.preAlertMeters = route.preAlertMeters
        self.approachingMeters = route.approachingMeters
        self.arrivalMeters = route.arrivalMeters
        self.averageSpeedKmh = max(route.averageSpeedKmh, 5)

        currentStage = .idle
        distanceToAlightMeters = nil
        gpsSignalWeak = false
        consecutiveQualifyingReadings = [:]
        minDistanceRecorded = .greatestFiniteMagnitude
        arrivalStageTriggeredAt = nil
        missedStopAlreadyTriggered = false
        accumulatedDistanceMeters = 0
        lastLocationForDistance = nil
    }

    func reset() {
        route = nil
        alightStop = nil
        stopAfterAlight = nil
        currentStage = .idle
        distanceToAlightMeters = nil
    }

    /// 由 LocationManager 每次拿到新位置时调用
    func processLocation(_ location: CLLocation) {
        guard let alightStop else { return }

        // 累计移动距离（用于行程历史里的"行程距离/平均速度"），这部分不受精度阈值限制，
        // 因为只是统计用途，稍有误差可以接受。
        if let last = lastLocationForDistance {
            accumulatedDistanceMeters += location.distance(from: last)
        }
        lastLocationForDistance = location

        let horizontalAccuracy = location.horizontalAccuracy
        guard horizontalAccuracy >= 0 else { return } // 负值代表无效定位

        let distance = location.distance(from: alightStop.location)

        guard horizontalAccuracy <= accuracyThreshold else {
            gpsSignalWeak = true
            onEvent?(.gpsWeak)
            return // 精度太差，本次读数不参与阶段判断，保持上一次状态
        }
        gpsSignalWeak = false
        distanceToAlightMeters = distance
        minDistanceRecorded = min(minDistanceRecorded, distance)

        evaluateStageProgress(distance: distance)
        evaluateMissedStop(currentDistanceToAlight: distance, location: location)
        updateETA(currentLocation: location)
    }

    private func evaluateStageProgress(distance: Double) {
        let candidateStage: ArrivalStage
        if distance <= arrivalMeters {
            candidateStage = .arrival
        } else if distance <= approachingMeters {
            candidateStage = .approaching
        } else if distance <= preAlertMeters {
            candidateStage = .preAlert
        } else {
            candidateStage = .idle
        }

        guard candidateStage > currentStage else { return }

        let readingsSoFar = (consecutiveQualifyingReadings[candidateStage] ?? 0) + 1
        consecutiveQualifyingReadings[candidateStage] = readingsSoFar

        guard readingsSoFar >= requiredConsecutiveReadings else { return }

        currentStage = candidateStage
        if candidateStage == .arrival {
            arrivalStageTriggeredAt = Date()
        }
        onEvent?(.stageChanged(candidateStage, distanceMeters: distance))
    }

    /// 坐过站检测：
    /// 1) 到站提醒已经触发过一段时间（给用户下车的合理时间窗口），但行程仍未结束；
    /// 2) 且用户距离目标站的距离明显比历史最小距离更大（说明车继续往前开，越开越远）；
    /// 3) 或者用户距"下一站"比距目标站更近，说明已经开过了目标站。
    private func evaluateMissedStop(currentDistanceToAlight: Double, location: CLLocation) {
        guard !missedStopAlreadyTriggered else { return }
        guard currentStage == .arrival, let triggeredAt = arrivalStageTriggeredAt else { return }

        let secondsSinceArrivalStage = Date().timeIntervalSince(triggeredAt)
        guard secondsSinceArrivalStage > 60 else { return } // 给至少 1 分钟的下车缓冲时间

        let movedAwaySignificantly = currentDistanceToAlight > minDistanceRecorded + 200

        var passedByNextStop = false
        if let nextStop = stopAfterAlight {
            let distanceToNext = location.distance(from: nextStop.location)
            passedByNextStop = distanceToNext < currentDistanceToAlight
        }

        if movedAwaySignificantly || passedByNextStop {
            missedStopAlreadyTriggered = true
            onEvent?(.missedStopSuspected)
        }
    }

    /// 车辆到站预测：优先使用众包实时定位计算的速度，没有的话退回到路线的平均时速估算。
    /// 这个方法只在 ActiveTripView 展示"预计到站"文案时调用一次性快照，
    /// 真正的众包计算发生在服务端，这里仅做"没有众包数据时"的兜底估算。
    private func updateETA(currentLocation: CLLocation) {
        guard let distance = distanceToAlightMeters else { return }
        let speedMps = averageSpeedKmh * 1000 / 3600
        guard speedMps > 0 else { return }
        let etaSeconds = distance / speedMps
        let estimate = ETAEstimate(etaSeconds: etaSeconds, source: .staticAverage)
        latestETA = estimate
        onEvent?(.etaUpdated(estimate))
    }

    /// 允许用众包车辆数据覆盖静态估算（由 APIClient 拉取到 LiveVehicle 后调用）
    func applyCrowdsourcedETA(_ estimate: ETAEstimate) {
        latestETA = estimate
        onEvent?(.etaUpdated(estimate))
    }
}
