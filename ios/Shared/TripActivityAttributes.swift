import Foundation
import ActivityKit

/// Live Activity 的数据结构。这个文件需要同时被主 App 和 Widget 扩展这两个 Target 编译，
/// 所以放在 ios/Shared 目录，并在 project.yml 里把它同时加入两个 target 的 sources。
struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var distanceMeters: Double
        var etaSeconds: TimeInterval?
        var stageDescription: String
    }

    var routeName: String
    var direction: String
    var alightStopName: String
}
