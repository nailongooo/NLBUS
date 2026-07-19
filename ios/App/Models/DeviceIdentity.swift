import Foundation

/// 生成并持久化一个匿名设备号。
/// 因为 App 不强制登录，公开路线的"创建者"字段以及众包定位上报都需要一个匿名标识，
/// 而不是真实身份信息，避免不必要的隐私风险。
final class DeviceIdentity {
    static let shared = DeviceIdentity()
    private let key = "anonymous_device_id"

    let deviceId: String

    private init() {
        if let existing = UserDefaults.standard.string(forKey: key) {
            deviceId = existing
        } else {
            let newId = "dev-" + UUID().uuidString.prefix(12)
            UserDefaults.standard.set(String(newId), forKey: key)
            deviceId = String(newId)
        }
    }
}
