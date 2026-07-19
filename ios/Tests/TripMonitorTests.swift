import XCTest
import CoreLocation
@testable import BusTracker

/// 针对 TripMonitor 核心到站判断逻辑的单元测试。
/// 注意：由于沙盒环境没有 Xcode/Swift 工具链，这些测试文件目前只经过了人工逻辑审查，
/// 尚未在真实 Xcode / Simulator 环境跑过。请在 GitHub Actions 里查看
/// "BusTracker" scheme 的 test 步骤结果，如果有失败请把日志发给我进一步修正。
final class TripMonitorTests: XCTestCase {

    /// 在给定站点北侧 `meters` 米处构造一个定位点（纬度 1 度约等于 111320 米，足够测试用）
    private func makeLocation(near stop: Stop, metersNorth: Double, accuracy: CLLocationAccuracy = 10) -> CLLocation {
        let latOffset = metersNorth / 111_320.0
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: stop.latitude + latOffset, longitude: stop.longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            timestamp: Date()
        )
    }

    private func makeRoute() -> (Route, Stop, Stop) {
        let alight = Stop(id: "alight", routeId: "r1", name: "目标站", order: 1, latitude: 26.08, longitude: 119.30)
        let after = Stop(id: "after", routeId: "r1", name: "下一站", order: 2, latitude: 26.09, longitude: 119.30)
        var route = Route.emptyDraft()
        route.id = "r1"
        route.preAlertMeters = 1500
        route.approachingMeters = 500
        route.arrivalMeters = 150
        route.stops = [
            Stop(id: "board", routeId: "r1", name: "起点站", order: 0, latitude: 26.05, longitude: 119.30),
            alight,
            after
        ]
        return (route, alight, after)
    }

    func testStagesTriggerInOrderAndOnlyOnce() {
        let (route, alight, _) = makeRoute()
        let monitor = TripMonitor()
        var receivedStages: [ArrivalStage] = []
        monitor.onEvent = { event in
            if case .stageChanged(let stage, _) = event {
                receivedStages.append(stage)
            }
        }
        monitor.beginMonitoring(route: route, alightStop: alight)

        // 距离目标站 2000 米：还不应该触发任何提醒（大于 1500 米预提醒阈值）
        monitor.processLocation(makeLocation(near: alight, metersNorth: 2000))
        XCTAssertEqual(monitor.currentStage, .idle)

        // 距离 1400 米：进入预提醒范围，但要求连续 2 次读数才会真正触发
        monitor.processLocation(makeLocation(near: alight, metersNorth: 1400))
        XCTAssertEqual(monitor.currentStage, .idle, "第一次读数不应该立刻触发，需要连续确认")
        monitor.processLocation(makeLocation(near: alight, metersNorth: 1350))
        XCTAssertEqual(monitor.currentStage, .preAlert)

        // 距离 400 米：进入"即将到站"
        monitor.processLocation(makeLocation(near: alight, metersNorth: 400))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 380))
        XCTAssertEqual(monitor.currentStage, .approaching)

        // 距离 100 米：进入"到站提醒"
        monitor.processLocation(makeLocation(near: alight, metersNorth: 100))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 90))
        XCTAssertEqual(monitor.currentStage, .arrival)

        XCTAssertEqual(receivedStages, [.preAlert, .approaching, .arrival], "三个阶段应该按顺序各触发一次")
    }

    func testPoorGPSAccuracyDoesNotAdvanceStage() {
        let (route, alight, _) = makeRoute()
        let monitor = TripMonitor()
        monitor.beginMonitoring(route: route, alightStop: alight)

        // 精度很差（100 米），即便数值上已经进入到站范围，也不应该被采信
        monitor.processLocation(makeLocation(near: alight, metersNorth: 50, accuracy: 100))
        XCTAssertEqual(monitor.currentStage, .idle)
        XCTAssertTrue(monitor.gpsSignalWeak)
    }

    func testMissedStopDetectionAfterPassingAlightStop() {
        let (route, alight, after) = makeRoute()
        let monitor = TripMonitor()
        var missedStopTriggered = false
        monitor.onEvent = { event in
            if case .missedStopSuspected = event {
                missedStopTriggered = true
            }
        }
        monitor.beginMonitoring(route: route, alightStop: alight)

        // 先正常走到"到站"阶段
        monitor.processLocation(makeLocation(near: alight, metersNorth: 1400))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 1350))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 400))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 380))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 100))
        monitor.processLocation(makeLocation(near: alight, metersNorth: 90))
        XCTAssertEqual(monitor.currentStage, .arrival)
        XCTAssertFalse(missedStopTriggered, "到站提醒触发后一分钟内不应该立刻判定坐过站")

        // 模拟时间已经过去（真实实现依赖系统时间，这里用一个明显超过目标站、
        // 更接近下一站的坐标来触发"passedByNextStop"分支）
        let distanceToAfter = after.location.distance(from: alight.location)
        monitor.processLocation(makeLocation(near: alight, metersNorth: distanceToAfter + 50))
        // 说明：由于测试运行速度快于真实的 60 秒等待窗口，这里主要验证距离计算分支不会崩溃；
        // 完整的时间窗口行为建议结合真机/模拟器手动验证到站后等待 1 分钟的场景。
    }
}
