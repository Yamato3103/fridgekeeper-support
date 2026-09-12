import MapKit
import Foundation

/// スポット検索。
///
/// `MKLocalSearch` は無料・無制限で、API キーも課金設定も要らない。
/// ただし日本の小規模店舗の網羅性は Google に劣るため、
/// 将来 Google Places API へ差し替えられるよう、検索はこのプロトコル越しに呼ぶ。
/// 差し替えるのは検索だけで、地図は MapKit のまま維持できる。
@MainActor
protocol PlaceSearchProviding: AnyObject {
    func updateQuery(_ query: String, around region: MKCoordinateRegion?)
    func resolve(_ suggestion: PlaceSuggestion) async -> PlaceDraft?
}

/// 検索候補の1件。
struct PlaceSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String

    /// 座標の解決に使う。MKLocalSearchCompletion はそのままでは座標を持たない。
    fileprivate let completion: MKLocalSearchCompletion

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PlaceSuggestion, rhs: PlaceSuggestion) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class PlaceSearchService: NSObject, ObservableObject, PlaceSearchProviding {
    @Published private(set) var suggestions: [PlaceSuggestion] = []
    @Published private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func updateQuery(_ query: String, around region: MKCoordinateRegion?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            suggestions = []
            isSearching = false
            return
        }

        // 表示中の範囲を優先して候補を出す。同名チェーン店が多い日本では
        // これがあるかどうかで結果の使いやすさが大きく変わる。
        if let region {
            completer.region = region
        }

        isSearching = true
        completer.queryFragment = trimmed
    }

    /// 候補を実際の座標へ解決する。
    func resolve(_ suggestion: PlaceSuggestion) async -> PlaceDraft? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)

        guard
            let response = try? await search.start(),
            let item = response.mapItems.first
        else {
            return nil
        }

        return PlaceDraft(
            name: item.name ?? suggestion.title,
            coordinate: item.placemark.coordinate,
            category: PlaceCategory(pointOfInterest: item.pointOfInterestCategory),
            address: item.placemark.title,
            origin: .search
        )
    }
}

extension PlaceSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results.map {
                PlaceSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }
}

extension PlaceCategory {
    /// MapKit の POI 分類を、このアプリの分類へ寄せる。
    /// 取りこぼしても .other に落ちるだけで、ユーザーが登録画面で直せる。
    init(pointOfInterest category: MKPointOfInterestCategory?) {
        switch category {
        case .some(.restaurant), .some(.bakery), .some(.brewery), .some(.winery):
            self = .food
        case .some(.cafe):
            self = .cafe
        case .some(.hotel):
            self = .stay
        case .some(.nationalPark), .some(.park), .some(.beach), .some(.campground):
            self = .nature
        case .some(.museum), .some(.library), .some(.theater):
            self = .other
        case .some(.store), .some(.foodMarket):
            self = .shop
        default:
            self = .other
        }
    }
}
