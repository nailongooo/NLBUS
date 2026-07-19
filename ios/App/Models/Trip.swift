import Foundation
import SwiftData
import CoreLocation

/// 一次行程中的单个轨迹点。只保存在手机本地，绝不上传服务器（隐私要求）。
struct TrackPoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var speedMps: Double
}

/// 行程历史记录，使用 SwiftData 存储在设备本地。
@Model
final class Trip {
    var id: String
    var routeId: String
    var routeName: String
    var direction: String
    var boardStopName: String
    var boardStopOrder: Int
    var alightStopName: String
    var alightStopOrder: Int
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var averageSpeedKmh: Double
    /// 到站提醒是否被认为"准时"（到达提醒触发后一段时间内用户手动结束了行程）
    var arrivedOnAlert: Bool
    /// 是否触发过"疑似坐过站"提醒
    var missedStopTriggered: Bool
    /// 轨迹点，编码为 JSON 字符串存储（SwiftData 对复杂结构体数组的原生支持有限，这样最稳妥）
    var trackPointsData: Data?

    init(
        id: String = UUID().uuidString,
        routeId: String,
        routeName: String,
        direction: String,
        boardStopName: String,
        boardStopOrder: Int,
        alightStopName: String,
        alightStopOrder: Int,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.routeId = routeId
        self.routeName = routeName
        self.direction = direction
        self.boardStopName = boardStopName
        self.boardStopOrder = boardStopOrder
        self.alightStopName = alightStopName
        self.alightStopOrder = alightStopOrder
        self.startedAt = startedAt
        self.endedAt = nil
        self.distanceMeters = 0
        self.averageSpeedKmh = 0
        self.arrivedOnAlert = false
        self.missedStopTriggered = false
        self.trackPointsData = nil
    }

    var trackPoints: [TrackPoint] {
        get {
            guard let data = trackPointsData else { return [] }
            return (try? JSONDecoder().decode([TrackPoint].self, from: data)) ?? []
        }
        set {
            trackPointsData = try? JSONEncoder().encode(newValue)
        }
    }

    func appendTrackPoint(_ point: TrackPoint) {
        var points = trackPoints
        points.append(point)
        trackPoints = points
    }
}
