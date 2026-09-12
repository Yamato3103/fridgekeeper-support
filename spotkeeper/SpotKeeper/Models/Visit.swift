import Foundation
import SwiftData

/// 訪問がどこから記録されたか。
enum VisitSource: String, Sendable {
    /// 手動チェックイン。
    case manual
    /// ジオフェンスによる自動判定（V1.1）。
    case geofence
    /// 写真からのサジェストを承認して作成（V1.1）。
    case photo
}

/// 1回の訪問。チェックインするたびに1件増える。
///
/// メモ・評価・写真は Place ではなく Visit が持つため、
/// 同じ場所を何度訪れても、その回ごとの記録が独立して残る。
@Model
final class Visit {
    var id: UUID = UUID()
    var visitedAt: Date = Date()

    /// その訪問の記録。前回の内容を上書きすることはない。
    var memo: String = ""

    /// 0...5。0 は未評価を表す。
    var rating: Int = 0

    var cost: Int?
    var companions: String?

    var sourceRaw: String = VisitSource.manual.rawValue

    var place: Place?

    @Relationship(deleteRule: .cascade, inverse: \VisitPhoto.visit)
    var photos: [VisitPhoto]? = []

    init(
        visitedAt: Date = .now,
        memo: String = "",
        rating: Int = 0,
        cost: Int? = nil,
        companions: String? = nil,
        source: VisitSource = .manual
    ) {
        self.id = UUID()
        self.visitedAt = visitedAt
        self.memo = memo
        self.rating = rating
        self.cost = cost
        self.companions = companions
        self.sourceRaw = source.rawValue
        self.photos = []
    }
}

extension Visit {
    var source: VisitSource {
        get { VisitSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var sortedPhotos: [VisitPhoto] {
        (photos ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var hasDetails: Bool {
        !memo.isEmpty || rating > 0 || cost != nil
            || !(companions ?? "").isEmpty || !(photos ?? []).isEmpty
    }
}
