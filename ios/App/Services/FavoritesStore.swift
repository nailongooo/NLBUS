import Foundation

/// 收藏路线只保存在本机（因为整个 App 默认不强制登录），用 UserDefaults 存一个 Route 的 JSON 列表即可，
/// 数据量很小，不需要上 SwiftData。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    private let key = "favorite_routes_v1"

    @Published private(set) var favorites: [Route] = []

    private init() {
        load()
    }

    func isFavorite(_ routeId: String) -> Bool {
        favorites.contains(where: { $0.id == routeId })
    }

    func toggle(_ route: Route) {
        if isFavorite(route.id) {
            favorites.removeAll { $0.id == route.id }
        } else {
            favorites.append(route)
        }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder.api.decode([Route].self, from: data) else { return }
        favorites = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder.api.encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
