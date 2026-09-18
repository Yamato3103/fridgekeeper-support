import CoreLocation
import Foundation

/// 現在地の取得。
///
/// V1 で要求する権限は「使用中のみ」に限定する。常時許可は App Store 審査で
/// 用途説明を厳しく問われるため、近接通知を入れる V1.1 まで持ち込まない。
///
/// `CLLocationManager` のデリゲートは、マネージャを作ったのと同じキュー
/// （このクラスは View から生成されるのでメインキュー）に返ってくる。
/// そのため `@Published` はコールバック内で直に更新してよく、
/// クラスを `@MainActor` にして Task で包み直す必要はない。
/// むしろ `@MainActor` にすると `@StateObject` の初期化やデリゲート適合の側で
/// 分離の警告（Swift 6 ではエラー）を抱え込むことになる。
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// 一度だけ現在地を取る。地図の初期表示と、検索結果の距離順並べ替えに使う。
    func requestCurrentLocation() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        manager.requestLocation()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 位置が取れなくてもアプリは成立する。地図は日本全体の初期表示のままにする。
        #if DEBUG
        print("位置情報の取得に失敗: \(error.localizedDescription)")
        #endif
    }
}
