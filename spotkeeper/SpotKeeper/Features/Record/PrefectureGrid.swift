import Foundation

/// 制覇マップの1マス。
struct PrefectureTile: Identifiable, Hashable {
    /// `CLPlacemark.administrativeArea` から「都・府・県」を落とした表記。集計のキーになる。
    let name: String
    /// マスに載せる2文字表記。福島・福井・福岡のように1文字では潰れるものがあるため2文字にしてある。
    let short: String
    let row: Int
    let column: Int

    var id: String { name }
}

/// 47都道府県を格子状に並べた模式地図。
///
/// 正確な境界を描くなら国土数値情報の GeoJSON を同梱して `MKPolygon` で塗るのが本筋だが、
/// 数MBのデータを抱える割に、制覇率を眺めるという用途では形の正確さが効かない。
/// 位置関係が分かる格子なら、データ無し・描画も軽量で同じ目的を果たせる。
/// 実地図での塗り分けが欲しくなったら、この集計結果をそのまま overlay へ渡せばよい。
enum PrefectureGrid {
    static let columnCount = 12
    static let rowCount = 12

    static let tiles: [PrefectureTile] = [
        .init(name: "北海道", short: "北海", row: 0, column: 10),

        .init(name: "青森", short: "青森", row: 1, column: 9),
        .init(name: "秋田", short: "秋田", row: 2, column: 8),
        .init(name: "岩手", short: "岩手", row: 2, column: 9),
        .init(name: "山形", short: "山形", row: 3, column: 8),
        .init(name: "宮城", short: "宮城", row: 3, column: 9),
        .init(name: "新潟", short: "新潟", row: 4, column: 7),
        .init(name: "福島", short: "福島", row: 4, column: 8),

        .init(name: "石川", short: "石川", row: 5, column: 5),
        .init(name: "富山", short: "富山", row: 5, column: 6),
        .init(name: "群馬", short: "群馬", row: 5, column: 7),
        .init(name: "栃木", short: "栃木", row: 5, column: 8),
        .init(name: "茨城", short: "茨城", row: 5, column: 9),

        .init(name: "島根", short: "島根", row: 6, column: 2),
        .init(name: "鳥取", short: "鳥取", row: 6, column: 3),
        .init(name: "京都", short: "京都", row: 6, column: 4),
        .init(name: "福井", short: "福井", row: 6, column: 5),
        .init(name: "岐阜", short: "岐阜", row: 6, column: 6),
        .init(name: "長野", short: "長野", row: 6, column: 7),
        .init(name: "埼玉", short: "埼玉", row: 6, column: 8),
        .init(name: "千葉", short: "千葉", row: 6, column: 9),

        .init(name: "長崎", short: "長崎", row: 7, column: 0),
        .init(name: "福岡", short: "福岡", row: 7, column: 1),
        .init(name: "広島", short: "広島", row: 7, column: 2),
        .init(name: "岡山", short: "岡山", row: 7, column: 3),
        .init(name: "兵庫", short: "兵庫", row: 7, column: 4),
        .init(name: "大阪", short: "大阪", row: 7, column: 5),
        .init(name: "滋賀", short: "滋賀", row: 7, column: 6),
        .init(name: "愛知", short: "愛知", row: 7, column: 7),
        .init(name: "山梨", short: "山梨", row: 7, column: 8),
        .init(name: "東京", short: "東京", row: 7, column: 9),

        .init(name: "佐賀", short: "佐賀", row: 8, column: 0),
        .init(name: "大分", short: "大分", row: 8, column: 1),
        .init(name: "山口", short: "山口", row: 8, column: 2),
        .init(name: "香川", short: "香川", row: 8, column: 3),
        .init(name: "徳島", short: "徳島", row: 8, column: 4),
        .init(name: "奈良", short: "奈良", row: 8, column: 5),
        .init(name: "三重", short: "三重", row: 8, column: 6),
        .init(name: "静岡", short: "静岡", row: 8, column: 7),
        .init(name: "神奈川", short: "神奈", row: 8, column: 8),

        .init(name: "熊本", short: "熊本", row: 9, column: 1),
        .init(name: "宮崎", short: "宮崎", row: 9, column: 2),
        .init(name: "愛媛", short: "愛媛", row: 9, column: 3),
        .init(name: "高知", short: "高知", row: 9, column: 4),
        .init(name: "和歌山", short: "和歌", row: 9, column: 5),

        .init(name: "鹿児島", short: "鹿児", row: 10, column: 1),
        .init(name: "沖縄", short: "沖縄", row: 11, column: 0),
    ]

    private static let lookup: [String: PrefectureTile] = Dictionary(
        uniqueKeysWithValues: tiles.map { ($0.name, $0) }
    )

    static func tile(named name: String) -> PrefectureTile? { lookup[name] }

    /// `CLPlacemark.administrativeArea` は「東京都」「大阪府」「神奈川県」「北海道」の形で返る。
    /// 末尾の都・府・県を落として集計キーに揃える。北海道の「道」は落とさない。
    static func normalize(_ administrativeArea: String?) -> String? {
        guard var name = administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            return nil
        }

        if name == "北海道" { return name }

        if let last = name.last, "都府県".contains(last) {
            name.removeLast()
        }

        return lookup[name] != nil ? name : nil
    }

    /// 各行に並ぶマスを、列番号の順で返す。空き列は nil。
    static func row(_ index: Int) -> [PrefectureTile?] {
        let inRow = tiles.filter { $0.row == index }
        return (0..<columnCount).map { column in
            inRow.first { $0.column == column }
        }
    }
}
