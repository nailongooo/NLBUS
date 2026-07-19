import Foundation

/// 可选账号体系：整个 App 默认"不登录也能完整使用"（本机数据）。
/// 只有当用户主动选择注册/登录后，才会启用"以固定昵称提交公开路线"等增值功能。
struct UserAccount: Codable {
    var id: String
    var email: String
    var nickname: String
    var token: String
    var isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, nickname, token
        case isAdmin = "is_admin"
    }
}
