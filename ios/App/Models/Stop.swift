import Foundation
import CoreLocation

/// 单个站点信息（属于某条路线）
struct Stop: Identifiable, Codable, Hashable {
    var id: String
    var routeId: String
    var name: String
    /// 在路线中的顺序，从 0 开始
    var order: Int
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, routeId = "route_id", name, order, latitude, longitude
    }
}
