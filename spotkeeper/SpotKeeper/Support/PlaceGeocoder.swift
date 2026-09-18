import CoreLocation
import Foundation

/// 座標から住所・都道府県・市区町村を引く。
///
/// `CLGeocoder` には回数制限があり、連続して叩くと失敗する。
/// そのためスポット登録時に**一度だけ**呼び、結果は Place に保存して以後は再取得しない。
/// 制覇マップの集計もこの保存値を使うため、全件を一括変換する処理は作らない。
enum PlaceGeocoder {

    struct Address {
        var formatted: String?
        var prefecture: String?
        var municipality: String?
    }

    /// 失敗しても nil を返すだけで、登録そのものは成立させる。
    /// 住所が空でもスポットとしては使えるため、ここでユーザーを止めない。
    static func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> Address? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        guard
            let placemarks = try? await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "ja_JP")
            ),
            let placemark = placemarks.first
        else {
            return nil
        }

        return Address(
            formatted: formatted(from: placemark),
            prefecture: placemark.administrativeArea,
            municipality: placemark.locality ?? placemark.subAdministrativeArea
        )
    }

    /// 日本の住所表記に合わせて「都道府県 市区町村 町名 番地」の順で組む。
    private static func formatted(from placemark: CLPlacemark) -> String? {
        let components = [
            placemark.administrativeArea,
            placemark.locality ?? placemark.subAdministrativeArea,
            placemark.thoroughfare,
            placemark.subThoroughfare,
        ].compactMap { $0 }

        return components.isEmpty ? nil : components.joined()
    }
}
