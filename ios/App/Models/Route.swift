import Foundation

/// 路线的审核状态
enum RouteStatus: String, Codable, CaseIterable, Hashable {
    case privateOnly = "private"   // 仅创建者自己可见
    case pending = "pending"       // 已提交公开审核，等待管理员处理
    case publicApproved = "public" // 管理员审核通过，公开可见
    case rejected = "rejected"     // 审核未通过

    var displayName: String {
        switch self {
        case .privateOnly: return NSLocalizedString("route.status.private", comment: "")
        case .pending: return NSLocalizedString("route.status.pending", comment: "")
        case .publicApproved: return NSLocalizedString("route.status.public", comment: "")
        case .rejected: return NSLocalizedString("route.status.rejected", comment: "")
        }
    }
}

/// 路线来源，帮助区分数据是从哪里来的
enum RouteSource: String, Codable, Hashable {
    case builtin      // 内置测试路线
    case userCreated = "user_created"   // 用户在 App 内手动创建
    case userUploaded = "user_uploaded" // 用户上传文件导入
    case serverOfficial = "server_official" // 管理员在后台录入
    case gtfsImport = "gtfs_import"     // GTFS / CSV 批量导入
}

/// 一条完整的路线（对应你需求里列出的所有字段）
struct Route: Identifiable, Codable, Hashable {
    var id: String
    var name: String                 // 路线名称，例如 "1路公交"
    var direction: String            // 方向，例如 "火车站 → 大学城"
    var summary: String?             // 路线说明
    var colorHex: String             // 路线图标/颜色，例如 "#3A7DFF"
    var iconSystemName: String       // SF Symbol 名称，例如 "bus.fill"
    var creatorId: String?           // 创建者（匿名设备号或账号 id），可为空
    var creatorDisplayName: String?  // 展示用创建者名称
    var isPublic: Bool               // 是否公开
    var status: RouteStatus
    var source: RouteSource
    var updatedAt: Date
    var createdAt: Date

    // 公交属性
    var fareDescription: String?     // 票价说明，例如 "全程2元，刷卡1.5元"
    var firstBusTime: String?        // 首班车时间，例如 "05:30"
    var lastBusTime: String?         // 末班车时间，例如 "22:30"
    var headwayMinutes: Int?         // 发车间隔（分钟）
    var operatorCompany: String?     // 运营公司

    // 提醒相关
    var preAlertMeters: Double       // 预提醒距离，默认 1500
    var approachingMeters: Double    // 即将到站距离，默认 500
    var arrivalMeters: Double        // 到站提醒距离，默认 150
    var averageSpeedKmh: Double      // 无众包数据时用于估算 ETA 的默认平均时速

    var stops: [Stop]

    enum CodingKeys: String, CodingKey {
        case id, name, direction, summary
        case colorHex = "color_hex"
        case iconSystemName = "icon_system_name"
        case creatorId = "creator_id"
        case creatorDisplayName = "creator_display_name"
        case isPublic = "is_public"
        case status, source
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case fareDescription = "fare_description"
        case firstBusTime = "first_bus_time"
        case lastBusTime = "last_bus_time"
        case headwayMinutes = "headway_minutes"
        case operatorCompany = "operator_company"
        case preAlertMeters = "pre_alert_meters"
        case approachingMeters = "approaching_meters"
        case arrivalMeters = "arrival_meters"
        case averageSpeedKmh = "average_speed_kmh"
        case stops
    }

    static func emptyDraft() -> Route {
        Route(
            id: UUID().uuidString,
            name: "",
            direction: "",
            summary: nil,
            colorHex: "#3A7DFF",
            iconSystemName: "bus.fill",
            creatorId: DeviceIdentity.shared.deviceId,
            creatorDisplayName: nil,
            isPublic: false,
            status: .privateOnly,
            source: .userCreated,
            updatedAt: Date(),
            createdAt: Date(),
            fareDescription: nil,
            firstBusTime: nil,
            lastBusTime: nil,
            headwayMinutes: nil,
            operatorCompany: nil,
            preAlertMeters: 1500,
            approachingMeters: 500,
            arrivalMeters: 150,
            averageSpeedKmh: 22,
            stops: []
        )
    }

    /// 内置的测试路线，保证第一次打开 App 就有数据可用，即使还没有连上后端
    static func builtinSamples() -> [Route] {
        let now = Date()
        let stops1 = [
            Stop(id: "b1-0", routeId: "builtin-1", name: "火车站", order: 0, latitude: 26.0798, longitude: 119.2989),
            Stop(id: "b1-1", routeId: "builtin-1", name: "五四广场", order: 1, latitude: 26.0824, longitude: 119.2953),
            Stop(id: "b1-2", routeId: "builtin-1", name: "东街口", order: 2, latitude: 26.0876, longitude: 119.3018),
            Stop(id: "b1-3", routeId: "builtin-1", name: "大学城", order: 3, latitude: 26.0961, longitude: 119.3182)
        ]
        return [
            Route(
                id: "builtin-1",
                name: "示例 1 路（测试路线）",
                direction: "火车站 → 大学城",
                summary: "这是内置的示例路线，方便你在没有联网/没有真实数据时也能体验完整流程。",
                colorHex: "#3A7DFF",
                iconSystemName: "bus.fill",
                creatorId: nil,
                creatorDisplayName: "系统内置",
                isPublic: true,
                status: .publicApproved,
                source: .builtin,
                updatedAt: now,
                createdAt: now,
                fareDescription: "全程 2 元",
                firstBusTime: "05:30",
                lastBusTime: "22:30",
                headwayMinutes: 12,
                operatorCompany: "示例公交集团",
                preAlertMeters: 1500,
                approachingMeters: 500,
                arrivalMeters: 150,
                averageSpeedKmh: 20,
                stops: stops1
            )
        ]
    }
}
