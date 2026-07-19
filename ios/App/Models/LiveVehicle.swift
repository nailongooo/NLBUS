import Foundation
import CoreLocation

/// 服务器根据"正在乘车的用户们"匿名上报的定位聚合出的车辆大致位置。
/// 这是众包方案，不依赖任何第三方地图公司的公交实时到站 API。
struct LiveVehicle: Identifiable, Codable {
    var id: String
    var routeId: String
    var latitude: Double
    var longitude: Double
    var headingDegrees: Double?
    var speedKmh: Double?
    var nearestStopOrder: Int?
    var reportedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case routeId = "route_id"
        case latitude, longitude
        case headingDegrees = "heading_degrees"
        case speedKmh = "speed_kmh"
        case nearestStopOrder = "nearest_stop_order"
        case reportedAt = "reported_at"
    }
}

/// ETA 预测结果，附带"数据来源"以便在界面上诚实地告诉用户这是不是真实数据
struct ETAEstimate {
    enum Source: Equatable {
        case crowdsourced   // 有其他乘客的众包定位
        case staticAverage  // 没有众包数据，用路线平均时速估算
    }
    var etaSeconds: TimeInterval
    var source: Source
}
