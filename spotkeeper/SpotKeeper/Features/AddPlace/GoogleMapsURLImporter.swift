import CoreLocation
import Foundation

/// 経路3: Google マップの共有 URL からスポットを取り込む。
///
/// Google マップで店を探す人は多いので、検索品質だけ Google を借りられると
/// Apple マップの弱点（小規模店の網羅性）が実質的に埋まる。費用はかからない。
///
/// ただしこれは Google が公式にサポートする使い方ではない。
/// URL の形式が変われば座標を取り出せなくなるため、
/// **失敗したら地図上で手動指定へ逃がす導線を必ず残すこと**。
enum GoogleMapsURLImporter {

    enum ImportError: LocalizedError {
        case notGoogleMaps
        case unreachable
        case coordinateNotFound

        var errorDescription: String? {
            switch self {
            case .notGoogleMaps:
                "Google マップの URL ではないようです。"
            case .unreachable:
                "URL を開けませんでした。通信状況を確認してください。"
            case .coordinateNotFound:
                "この URL からは位置を取り出せませんでした。地図を長押しして手で登録してください。"
            }
        }
    }

    static func canHandle(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return host.contains("google.") || host.contains("goo.gl")
    }

    /// 短縮 URL はリダイレクトを解決してから座標を探す。
    static func makeDraft(from url: URL) async throws -> PlaceDraft {
        guard canHandle(url) else { throw ImportError.notGoogleMaps }

        let resolved = try await resolveRedirects(of: url)

        guard let coordinate = extractCoordinate(from: resolved) else {
            throw ImportError.coordinateNotFound
        }

        return PlaceDraft(
            name: extractName(from: resolved) ?? "",
            coordinate: coordinate,
            origin: .googleMapsURL
        )
    }

    private static func resolveRedirects(of url: URL) async throws -> URL {
        // maps.app.goo.gl は短縮 URL。展開後の URL に座標が入っている。
        guard let (_, response) = try? await URLSession.shared.data(from: url) else {
            throw ImportError.unreachable
        }
        return response.url ?? url
    }

    /// 展開後の URL には座標が複数の形で現れる。精度の高い順に拾う。
    ///
    ///   1. `!3d35.6586!4d139.7454` — その場所そのものの座標
    ///   2. `@35.6586,139.7454,17z` — 表示中の地図の中心（ピンとずれることがある）
    ///   3. `?q=35.6586,139.7454`   — 座標を直接指定した共有
    static func extractCoordinate(from url: URL) -> CLLocationCoordinate2D? {
        let text = url.absoluteString

        let patterns = [
            #"!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)"#,
            #"@(-?\d+\.\d+),(-?\d+\.\d+)"#,
            #"[?&](?:q|query|destination|center)=(-?\d+\.\d+),\s*(-?\d+\.\d+)"#,
        ]

        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                match.numberOfRanges == 3,
                let latRange = Range(match.range(at: 1), in: text),
                let lonRange = Range(match.range(at: 2), in: text),
                let latitude = Double(text[latRange]),
                let longitude = Double(text[lonRange])
            else {
                continue
            }

            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                return coordinate
            }
        }

        return nil
    }

    /// `/maps/place/店名/@...` の店名部分。取れなければ空のまま登録画面で入力してもらう。
    static func extractName(from url: URL) -> String? {
        let components = url.pathComponents
        guard
            let placeIndex = components.firstIndex(of: "place"),
            components.index(after: placeIndex) < components.endIndex
        else {
            return nil
        }

        let raw = components[components.index(after: placeIndex)]
        let decoded = raw
            .replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding ?? raw

        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        // 座標だけの place セグメント（例: "35.6586,139.7454"）は名前ではない。
        if trimmed.isEmpty || trimmed.range(of: #"^-?\d+\.\d+,-?\d+\.\d+$"#, options: .regularExpression) != nil {
            return nil
        }

        return trimmed
    }
}
