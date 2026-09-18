import CoreLocation
import Foundation
import SwiftData

/// 登録したスポット。「行きたい場所」も「行った場所」も同じ Place で表し、
/// 訪問したかどうかは紐づく Visit の有無で判断する。
///
/// CloudKit と併用するため、モデル定義には3つの制約がかかる。
///   1. 全プロパティに既定値を持たせるか Optional にする
///   2. `@Attribute(.unique)` は使えない（一意性はアプリ側で担保する）
///   3. リレーションは必ず Optional にする
@Model
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var address: String?

    var categoryRaw: String = PlaceCategory.other.rawValue

    /// 行きたい度。0...3。2以上で地図上の扱いが「優先」に変わる。
    var wishLevel: Int = 0

    /// 場所そのものへの恒久メモ。駐車場の位置、定休日、予約方法など、
    /// 何度訪れても変わらない情報を置く。訪問ごとの感想は Visit.memo に入る。
    var note: String = ""

    /// 逆ジオコーディングの結果をキャッシュする。CLGeocoder には回数制限があるため、
    /// 登録時に一度だけ引いてここへ保存し、以後は再取得しない。
    var prefecture: String?
    var municipality: String?

    var createdAt: Date = Date()
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Visit.place)
    var visits: [Visit]? = []

    init(
        name: String,
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory = .other,
        wishLevel: Int = 0,
        address: String? = nil,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.categoryRaw = category.rawValue
        self.wishLevel = wishLevel
        self.address = address
        self.note = note
        self.createdAt = createdAt
        self.isArchived = false
        self.visits = []
    }
}

extension Place {
    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var category: PlaceCategory {
        get { PlaceCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// 訪問回数はプロパティとして保存しない。
    /// カウンタを別途持つと、複数端末で同時にチェックインしたときに値がずれ、
    /// CloudKit の競合解決では正しい値へ戻せなくなるため、常に算出する。
    var visitCount: Int { visits?.count ?? 0 }

    var isVisited: Bool { visitCount > 0 }

    /// 新しい訪問が先頭に来る順。訪問履歴の表示順と一致する。
    var sortedVisits: [Visit] {
        (visits ?? []).sorted { $0.visitedAt > $1.visitedAt }
    }

    var lastVisitedAt: Date? { sortedVisits.first?.visitedAt }

    var isVisitedToday: Bool {
        guard let lastVisitedAt else { return false }
        return Calendar.current.isDateInToday(lastVisitedAt)
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: location)
    }
}
