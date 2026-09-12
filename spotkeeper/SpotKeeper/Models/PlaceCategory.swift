import Foundation

/// スポットの分類。
///
/// SwiftData + CloudKit ではカスタム型をそのまま保存するより
/// String の raw value を持たせるほうがスキーマ移行に強いため、
/// モデル側は `categoryRaw` を保持し、読み書きはこの enum を介して行う。
enum PlaceCategory: String, CaseIterable, Identifiable, Sendable {
    case food
    case cafe
    case onsen
    case stay
    case shrine
    case nature
    case shop
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food:   "飲食"
        case .cafe:   "カフェ"
        case .onsen:  "温泉"
        case .stay:   "宿"
        case .shrine: "社寺"
        case .nature: "自然"
        case .shop:   "買い物"
        case .other:  "その他"
        }
    }

    /// ピンの中に表示する SF Symbol。
    var symbolName: String {
        switch self {
        case .food:   "fork.knife"
        case .cafe:   "cup.and.saucer.fill"
        case .onsen:  "drop.fill"
        case .stay:   "bed.double.fill"
        case .shrine: "building.columns.fill"
        case .nature: "leaf.fill"
        case .shop:   "bag.fill"
        case .other:  "mappin"
        }
    }
}
