import SwiftData
import SwiftUI

/// 制覇マップ。訪問した都道府県が塗られていく。
///
/// 集計は Place に保存済みの `prefecture` を読むだけで、
/// ここで逆ジオコーディングは一切走らせない。CLGeocoder には回数制限があり、
/// 全件を一括変換しようとすると確実に詰まるため。
struct ConquestMapView: View {
    @Query private var allPlaces: [Place]
    @State private var selected: PrefectureTile?

    private var places: [Place] { allPlaces.filter { !$0.isArchived } }

    /// 都道府県ごとの訪問回数。未訪問のスポットは数えない。
    private var visitCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for place in places where place.isVisited {
            guard let key = PrefectureGrid.normalize(place.prefecture) else { continue }
            counts[key, default: 0] += place.visitCount
        }
        return counts
    }

    private var conqueredCount: Int { visitCounts.count }

    private var conquestRate: Double {
        Double(conqueredCount) / Double(PrefectureGrid.tiles.count)
    }

    /// 逆ジオコーディングに失敗して都道府県が特定できていない訪問済みスポット。
    /// 黙って数字を小さく見せるより、件数を出しておくほうが誠実。
    private var unresolvedCount: Int {
        places.filter { $0.isVisited && PrefectureGrid.normalize($0.prefecture) == nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                header
                grid
                legend

                if unresolvedCount > 0 {
                    Text("都道府県を特定できていない訪問済みスポットが \(unresolvedCount) 件あります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("制覇マップ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { tile in
            PrefectureDetailSheet(tile: tile, places: places(in: tile))
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - 見出し

    private var header: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(conqueredCount)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("/ 47")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("制覇率 \(Int((conquestRate * 100).rounded())) %")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            ProgressView(value: conquestRate)
                .tint(.pinVisited)
                .frame(maxWidth: 220)
                .padding(.top, 4)
        }
    }

    // MARK: - 格子

    private var grid: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 3
            let available = geometry.size.width
            let side = (available - spacing * CGFloat(PrefectureGrid.columnCount - 1))
                / CGFloat(PrefectureGrid.columnCount)

            VStack(spacing: spacing) {
                ForEach(0..<PrefectureGrid.rowCount, id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(Array(PrefectureGrid.row(rowIndex).enumerated()), id: \.offset) { _, tile in
                            if let tile {
                                PrefectureCell(
                                    tile: tile,
                                    visitCount: visitCounts[tile.name] ?? 0,
                                    side: side
                                )
                                .onTapGesture { selected = tile }
                            } else {
                                Color.clear
                                    .frame(width: side, height: side)
                            }
                        }
                    }
                }
            }
        }
        // 列数と行数が同じ正方マスの格子なので、全体も正方形になる。
        // これで GeometryReader が高さを決められない問題を、画面幅を直接見ずに解ける。
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 16)
    }

    // MARK: - 凡例

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(ConquestLevel.allCases) { level in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level.fill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(level.border, lineWidth: level == .none ? 1 : 0)
                        }
                        .frame(width: 12, height: 12)
                    Text(level.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func places(in tile: PrefectureTile) -> [Place] {
        places
            .filter { PrefectureGrid.normalize($0.prefecture) == tile.name }
            .sorted { $0.visitCount > $1.visitCount }
    }
}

/// 訪問回数を4段階に落としたもの。連続値で塗ると差が読み取れないため段階にする。
enum ConquestLevel: Int, CaseIterable, Identifiable {
    case none
    case light
    case medium
    case deep

    var id: Int { rawValue }

    init(visitCount: Int) {
        switch visitCount {
        case 0: self = .none
        case 1...2: self = .light
        case 3...5: self = .medium
        default: self = .deep
        }
    }

    var label: String {
        switch self {
        case .none: "未訪問"
        case .light: "1–2回"
        case .medium: "3–5回"
        case .deep: "6回以上"
        }
    }

    var fill: Color {
        switch self {
        case .none: .clear
        case .light: Color.pinVisited.opacity(0.28)
        case .medium: Color.pinVisited.opacity(0.62)
        case .deep: Color.pinVisited
        }
    }

    var border: Color {
        self == .none ? Color.pinIdle.opacity(0.45) : .clear
    }

    var textColor: Color {
        switch self {
        case .none: .secondary
        case .light, .medium: .primary
        case .deep: .pinLabel
        }
    }
}

private struct PrefectureCell: View {
    let tile: PrefectureTile
    let visitCount: Int
    let side: CGFloat

    private var level: ConquestLevel { ConquestLevel(visitCount: visitCount) }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(level.fill)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(level.border, lineWidth: level == .none ? 1 : 0)
            }
            .overlay {
                Text(tile.short)
                    .font(.system(size: side * 0.3, weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(level.textColor)
            }
            .frame(width: side, height: side)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                visitCount == 0 ? "\(tile.name)、未訪問" : "\(tile.name)、\(visitCount) 回訪問"
            )
    }
}

/// マスをタップしたときに出る、その都道府県のスポット一覧。
private struct PrefectureDetailSheet: View {
    let tile: PrefectureTile
    let places: [Place]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty {
                    ContentUnavailableView(
                        "まだスポットがありません",
                        systemImage: "mappin.slash",
                        description: Text("\(tile.name)に登録したスポットはありません。")
                    )
                } else {
                    List(places) { place in
                        HStack(spacing: 12) {
                            PlacePinView(place: place)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.body.weight(.medium))
                                Text(place.municipality ?? place.category.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if place.visitCount > 0 {
                                Text("\(place.visitCount)")
                                    .font(.footnote.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.pinVisited)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(tile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConquestMapView()
    }
    .modelContainer(SpotKeeperModelContainer.preview())
}
