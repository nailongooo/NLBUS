import Foundation

/// 管理员专用接口，走独立的 /api/admin/* 路径 + 独立的管理员 JWT（与普通用户账号体系完全分开）。
final class AdminAPIClient {
    static let shared = AdminAPIClient()

    private var baseURL: URL { APIClient.shared.baseURL }
    private var adminToken: String? {
        UserDefaults.standard.string(forKey: "admin_token")
    }

    struct AdminLoginResponse: Decodable {
        var token: String
    }

    func login(username: String, password: String) async throws -> String {
        var url = baseURL
        url.append(path: "admin/login")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIClient.APIError.server(NSLocalizedString("admin.login_failed", comment: ""))
        }
        let decoded = try JSONDecoder().decode(AdminLoginResponse.self, from: data)
        UserDefaults.standard.set(decoded.token, forKey: "admin_token")
        return decoded.token
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "admin_token")
    }

    var isLoggedIn: Bool { adminToken != nil }

    private func authorizedRequest<T: Decodable>(path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let token = adminToken else { throw APIClient.APIError.server(NSLocalizedString("admin.not_logged_in", comment: "")) }
        var url = baseURL
        url.append(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { req.httpBody = try JSONEncoder().encode(AnyEncodable(body)) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIClient.APIError.server(NSLocalizedString("admin.request_failed", comment: ""))
        }
        return try JSONDecoder.api.decode(T.self, from: data)
    }

    struct AdminStats: Decodable {
        var totalRoutes: Int
        var pendingRoutes: Int
        var totalFeedback: Int
        enum CodingKeys: String, CodingKey {
            case totalRoutes = "total_routes"
            case pendingRoutes = "pending_routes"
            case totalFeedback = "total_feedback"
        }
    }

    func fetchStats() async throws -> AdminStats {
        try await authorizedRequest(path: "admin/stats")
    }

    func fetchPendingRoutes() async throws -> [Route] {
        try await authorizedRequest(path: "admin/routes/pending")
    }

    func approveRoute(id: String) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await authorizedRequest(path: "admin/routes/\(id)/approve", method: "POST")
    }

    func rejectRoute(id: String) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await authorizedRequest(path: "admin/routes/\(id)/reject", method: "POST")
    }

    func deleteRoute(id: String) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await authorizedRequest(path: "admin/routes/\(id)", method: "DELETE")
    }

    func postAnnouncement(title: String, content: String, isPinned: Bool) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await authorizedRequest(path: "admin/announcements", method: "POST", body: [
            "title": title, "content": content, "is_pinned": isPinned ? "true" : "false"
        ] as [String: String])
    }
}
