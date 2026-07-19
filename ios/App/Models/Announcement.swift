import Foundation

/// 管理员发布的公告
struct Announcement: Identifiable, Codable {
    var id: String
    var title: String
    var content: String
    var createdAt: Date
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case createdAt = "created_at"
        case isPinned = "is_pinned"
    }
}
