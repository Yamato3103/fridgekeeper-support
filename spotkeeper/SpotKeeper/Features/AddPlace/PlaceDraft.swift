import CoreLocation
import Foundation

/// 登録前のスポット。
///
/// 検索・地図長押し・Google マップから共有・写真から、の4経路はいずれも
/// この Draft を作るところまでが仕事で、そこから先の確認画面と保存は共通化する。
/// 入口が増えても保存処理が分岐しないようにするための型。
struct PlaceDraft: Identifiable, Equatable {
    let id = UUID()

    var name: String
    var coordinate: CLLocationCoordinate2D
    var category: PlaceCategory
    var wishLevel: Int
    var address: String?
    var note: String

    /// どの経路から作られたか。確認画面の説明文を変えるために持つ。
    var origin: Origin

    enum Origin: Equatable {
        case search
        case mapLongPress
        case googleMapsURL
        case photo

        var label: String {
            switch self {
            case .search: "検索から"
            case .mapLongPress: "地図から"
            case .googleMapsURL: "Google マップから"
            case .photo: "写真から"
            }
        }
    }

    init(
        name: String = "",
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory = .other,
        wishLevel: Int = 1,
        address: String? = nil,
        note: String = "",
        origin: Origin
    ) {
        self.name = name
        self.coordinate = coordinate
        self.category = category
        self.wishLevel = wishLevel
        self.address = address
        self.note = note
        self.origin = origin
    }

    static func == (lhs: PlaceDraft, rhs: PlaceDraft) -> Bool {
        lhs.id == rhs.id
    }

    /// 保存できる状態か。名前だけは必須にする。
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CLLocationCoordinate2DIsValid(coordinate)
    }

    func makePlace() -> Place {
        Place(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            coordinate: coordinate,
            category: category,
            wishLevel: wishLevel,
            address: address,
            note: note
        )
    }
}
