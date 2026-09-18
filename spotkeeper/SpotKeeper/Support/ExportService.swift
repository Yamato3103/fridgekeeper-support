import Foundation

/// スポットと訪問記録の書き出し。
///
/// 無料でも使えるようにしておく。「いつでもデータを持ち出せる」という姿勢そのものが
/// 記録アプリの信頼になり、結果としてレビュー評価に返ってくる。
enum ExportService {

    enum Format: String, CaseIterable, Identifiable {
        case csv
        case geoJSON

        var id: String { rawValue }

        var label: String {
            switch self {
            case .csv: "CSV"
            case .geoJSON: "GeoJSON"
            }
        }

        var detail: String {
            switch self {
            case .csv: "表計算ソフトで開ける。訪問1件が1行。"
            case .geoJSON: "地図ソフトに読み込める。スポット1件が1地点。"
            }
        }

        var fileExtension: String {
            switch self {
            case .csv: "csv"
            case .geoJSON: "geojson"
            }
        }
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - 書き出し

    static func export(_ places: [Place], as format: Format) throws -> URL {
        let data: Data

        switch format {
        case .csv:
            // Excel は BOM が無い UTF-8 の CSV を Shift_JIS と誤認して日本語を化けさせる。
            let bom = Data([0xEF, 0xBB, 0xBF])
            data = bom + Data(makeCSV(places).utf8)
        case .geoJSON:
            data = try makeGeoJSON(places)
        }

        let name = "SpotKeeper-\(fileTimestamp()).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - CSV

    /// 訪問1件が1行。訪問がまだ無いスポットも、訪問側を空欄にして1行出す。
    /// 「行きたいが未訪問」のリストごと持ち出せないと、移行先で情報が欠ける。
    static func makeCSV(_ places: [Place]) -> String {
        let header = [
            "スポット名", "分類", "緯度", "経度", "住所", "都道府県", "市区町村",
            "行きたい度", "場所メモ",
            "訪問日時", "評価", "費用", "同行者", "訪問メモ", "写真枚数",
        ]

        var rows = [header.map(escape).joined(separator: ",")]

        for place in places.sorted(by: { $0.createdAt < $1.createdAt }) {
            let placeColumns = [
                place.name,
                place.category.label,
                String(place.latitude),
                String(place.longitude),
                place.address ?? "",
                place.prefecture ?? "",
                place.municipality ?? "",
                String(place.wishLevel),
                place.note,
            ]

            let visits = place.sortedVisits

            if visits.isEmpty {
                rows.append((placeColumns + Array(repeating: "", count: 6)).map(escape).joined(separator: ","))
                continue
            }

            for visit in visits {
                let visitColumns = [
                    timestampFormatter.string(from: visit.visitedAt),
                    visit.rating > 0 ? String(visit.rating) : "",
                    visit.cost.map(String.init) ?? "",
                    visit.companions ?? "",
                    visit.memo,
                    String(visit.sortedPhotos.count),
                ]
                rows.append((placeColumns + visitColumns).map(escape).joined(separator: ","))
            }
        }

        return rows.joined(separator: "\r\n")
    }

    /// 区切り文字・引用符・改行を含む値は引用符で囲み、内側の引用符は二重にする。
    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - GeoJSON

    static func makeGeoJSON(_ places: [Place]) throws -> Data {
        let features: [[String: Any]] = places
            .sorted { $0.createdAt < $1.createdAt }
            .map { place in
                var properties: [String: Any] = [
                    "name": place.name,
                    "category": place.category.label,
                    "wishLevel": place.wishLevel,
                    "visitCount": place.visitCount,
                    "createdAt": timestampFormatter.string(from: place.createdAt),
                ]

                if let address = place.address { properties["address"] = address }
                if let prefecture = place.prefecture { properties["prefecture"] = prefecture }
                if let municipality = place.municipality { properties["municipality"] = municipality }
                if !place.note.isEmpty { properties["note"] = place.note }

                properties["visits"] = place.sortedVisits.map { visit -> [String: Any] in
                    var entry: [String: Any] = [
                        "visitedAt": timestampFormatter.string(from: visit.visitedAt),
                        "photoCount": visit.sortedPhotos.count,
                    ]
                    if !visit.memo.isEmpty { entry["memo"] = visit.memo }
                    if visit.rating > 0 { entry["rating"] = visit.rating }
                    if let cost = visit.cost { entry["cost"] = cost }
                    if let companions = visit.companions { entry["companions"] = companions }
                    return entry
                }

                return [
                    "type": "Feature",
                    // GeoJSON の座標は [経度, 緯度] の順。緯度経度の順ではない。
                    "geometry": [
                        "type": "Point",
                        "coordinates": [place.longitude, place.latitude],
                    ],
                    "properties": properties,
                ]
            }

        let collection: [String: Any] = [
            "type": "FeatureCollection",
            "features": features,
        ]

        return try JSONSerialization.data(
            withJSONObject: collection,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: .now)
    }
}
