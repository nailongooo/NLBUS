import Foundation
import CoreLocation
import Combine

/// 封装 CoreLocation，只在"行程进行中"才打开后台定位权限对应的能力，
/// 行程结束立刻降级为不追踪，尽量减少耗电和隐私风险。
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isBackgroundTrackingActive: Bool = false

    /// 每次收到新位置就会调用，交给 TripMonitor 去做业务判断
    var onLocationUpdate: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // 至少移动 10 米才回调一次，省电
        authorizationStatus = manager.authorizationStatus
    }

    /// 首次使用时先申请"使用期间"权限。
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// 只有当用户明确点击"开始行程"，并且已经授权过 WhenInUse 后，
    /// 才升级申请"始终允许"，用于锁屏/后台继续提醒。
    func requestAlwaysAuthorizationIfNeeded() {
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    /// 开始一段行程的定位追踪（含后台）
    func startTripTracking() {
        manager.allowsBackgroundLocationUpdates = (authorizationStatus == .authorizedAlways)
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.activityType = .automotiveNavigation
        manager.startUpdatingLocation()
        isBackgroundTrackingActive = true
    }

    /// 行程结束/取消，立即停止后台定位，降低耗电和隐私风险
    func stopTripTracking() {
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        isBackgroundTrackingActive = false
    }

    /// 非行程状态下，例如"等车提醒"页面，只做前台的、低频率定位
    func startForegroundOnlyUpdates() {
        manager.allowsBackgroundLocationUpdates = false
        manager.startUpdatingLocation()
    }

    func stopForegroundOnlyUpdates() {
        if !isBackgroundTrackingActive {
            manager.stopUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        currentLocation = latest
        onLocationUpdate?(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 定位偶发失败很常见（例如刚从室内出来），这里不做致命处理，等待下一次回调。
        #if DEBUG
        print("LocationManager error: \(error.localizedDescription)")
        #endif
    }
}
