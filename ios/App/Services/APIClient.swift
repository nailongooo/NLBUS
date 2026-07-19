import Foundation

/// App 与你自建后端服务器之间的所有网络请求都通过这一个类完成。
/// 修改 baseURL 就能切换到你自己部署的服务器地址（部署教程见 docs/03-后端部署教程.md）。
final class APIClient {
    static let shared = APIClient()

    /// !! 部署好后端之后，请把这里换成你自己的域名 !!
    /// 例如："https://bus-api.yourdomain.com/api"
    var baseURL: URL = URL(string: "https://YOUR_DOMAIN_HERE/api")!

    private var authToken: String? {
        UserDefaults.standard.string(forKey: "auth_token")
    }

    enum APIError: LocalizedError {
        case invalidResponse
        case server(String)
        case decoding

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return NSLocalizedString("api.error.invalid_response", comment: "")
            case .server(let message): return message
            case .decoding: return NSLocalizedString("api.error.decoding", comment: "")
            }
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        var url = baseURL
        url.append(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DeviceIdentity.shared.deviceId, forHTTPHeaderField: "X-Device-Id")
        if requiresAuth, let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder.api.encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if !(200...299).contains(http.statusCode) {
            if let errorBody = try? JSONDecoder.api.decode(ServerErrorBody.self, from: data) {
                throw APIError.server(errorBody.message)
            }
            throw APIError.server("服务器返回状态码 \(http.statusCode)")
        }

        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    // MARK: - 路线

    func searchRoutes(keyword: String) async throws -> [Route] {
        try await request(path: "routes?keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    func fetchPublicRoutes() async throws -> [Route] {
        try await request(path: "routes")
    }

    func fetchRoute(id: String) async throws -> Route {
        try await request(path: "routes/\(id)")
    }

    func createRoute(_ route: Route) async throws -> Route {
        try await request(path: "routes", method: "POST", body: route, requiresAuth: false)
    }

    func submitRouteForReview(id: String) async throws -> Route {
        try await request(path: "routes/\(id)/submit", method: "POST")
    }

    func reportRoute(id: String, reason: String) async throws -> EmptyResponse {
        try await request(path: "routes/\(id)/report", method: "POST", body: ["reason": reason])
    }

    // MARK: - 众包车辆位置

    struct TripPing: Encodable {
        var routeId: String
        var latitude: Double
        var longitude: Double
        var speedKmh: Double
        var headingDegrees: Double
    }

    func sendTripPing(_ ping: TripPing) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request(path: "trips/ping", method: "POST", body: ping)
    }

    func fetchLiveVehicles(routeId: String) async throws -> [LiveVehicle] {
        try await request(path: "routes/\(routeId)/live-vehicles")
    }

    // MARK: - 反馈 / 公告

    func submitFeedback(content: String, contact: String?) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request(path: "feedback", method: "POST", body: ["content": content, "contact": contact ?? ""])
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        try await request(path: "announcements")
    }

    // MARK: - 账号（可选）

    func register(email: String, password: String, nickname: String) async throws -> UserAccount {
        try await request(path: "auth/register", method: "POST", body: ["email": email, "password": password, "nickname": nickname])
    }

    func login(email: String, password: String) async throws -> UserAccount {
        try await request(path: "auth/login", method: "POST", body: ["email": email, "password": password])
    }
}

// MARK: - JSON 编解码辅助（统一使用 snake_case <-> 驼峰 转换 与 ISO8601 时间）

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct ServerErrorBody: Decodable {
    var message: String
}

struct EmptyResponse: Decodable {}

/// 用于让 request(body:) 既能接收 Encodable 结构体，也能接收 [String: String] 字面量字典
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeClosure = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

// 注意：Swift 标准库里 Dictionary<String, String> 已经原生支持 Encodable，
// 不需要（也不能）再手写一遍一致的协议实现，否则会与标准库冲突导致编译报错。
