import CoreLocation
import Foundation
import SwiftData

/// 開発中に地図とリストの見た目を確認するためのサンプル。
///
/// 未訪問・優先・1回訪問・複数回訪問・本日訪問の5状態がすべて現れるように組んである。
/// 実データが入る前の空の画面では、ピンの状態設計を目で確かめられないため。
enum SampleData {

    @MainActor
    static func insert(into context: ModelContext) {
        for place in makePlaces() {
            context.insert(place)
        }
        try? context.save()
    }

    /// 既存データが1件も無いときだけサンプルを入れる。
    @MainActor
    static func seedIfEmpty(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Place>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        insert(into: context)
    }

    private static func makePlaces() -> [Place] {
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        }

        // 未訪問。まだ一度も行っていない。
        let takao = Place(
            name: "高尾山",
            coordinate: .init(latitude: 35.6251, longitude: 139.2436),
            category: .nature,
            wishLevel: 1,
            address: "東京都八王子市高尾町",
            note: "ケーブルカーは平日でも朝9時台から混む"
        )

        // 未訪問・優先。行きたい度が高いので地図上で目立つ。
        let kanazawa = Place(
            name: "金沢21世紀美術館",
            coordinate: .init(latitude: 36.5608, longitude: 136.6577),
            category: .other,
            wishLevel: 3,
            address: "石川県金沢市広坂1-2-1",
            note: "月曜休館。展覧会ゾーンは要予約"
        )

        // 訪問1回。
        let fushimi = Place(
            name: "伏見稲荷大社",
            coordinate: .init(latitude: 34.9671, longitude: 135.7727),
            category: .shrine,
            wishLevel: 2,
            address: "京都府京都市伏見区深草藪之内町68"
        )
        fushimi.visits = [
            Visit(
                visitedAt: daysAgo(96),
                memo: "千本鳥居は朝7時に着いたらほぼ貸し切りだった。山頂まで往復2時間。",
                rating: 5
            )
        ]

        // 複数回訪問。訪問ごとにメモが独立して残っていることを示すサンプル。
        let dogo = Place(
            name: "道後温泉本館",
            coordinate: .init(latitude: 33.8519, longitude: 132.7863),
            category: .onsen,
            wishLevel: 2,
            address: "愛媛県松山市道後湯之町5-6",
            note: "駐車場は本館前ではなく市営の第2が停めやすい"
        )
        dogo.visits = [
            Visit(visitedAt: daysAgo(412), memo: "改修中で一部だけ入浴。それでも雰囲気は十分。", rating: 4, cost: 460),
            Visit(visitedAt: daysAgo(210), memo: "二階席を利用。湯上がりの坊っちゃん団子がよかった。", rating: 5, cost: 1250),
            Visit(visitedAt: daysAgo(31), memo: "平日夕方は空いている。次は霊の湯を試す。", rating: 5, cost: 460),
        ]

        // 本日訪問。チェックイン直後の見え方を確認するためのサンプル。
        let tsuruoka = Place(
            name: "鶴岡八幡宮",
            coordinate: .init(latitude: 35.3259, longitude: 139.5563),
            category: .shrine,
            wishLevel: 1,
            address: "神奈川県鎌倉市雪ノ下2-1-31"
        )
        tsuruoka.visits = [
            Visit(visitedAt: .now, memo: "", rating: 0)
        ]

        return [takao, kanazawa, fushimi, dogo, tsuruoka]
    }
}
