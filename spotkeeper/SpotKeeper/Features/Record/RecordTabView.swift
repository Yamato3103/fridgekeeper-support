import SwiftData
import SwiftUI

/// 記録タブ。訪問タイムライン、件数サマリー、制覇マップへの入口。
struct RecordTabView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]
    @Query private var places: [Place]

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("チェックインすると、ここに訪問の記録が並びます。")
                    )
                } else {
                    List {
                        Section {
                            summary
                        }

                        Section {
                            NavigationLink {
                                ConquestMapView()
                            } label: {
                                LabeledContent {
                                    Text("\(conqueredPrefectureCount) / 47")
                                        .monospacedDigit()
                                        .foregroundStyle(.pinVisited)
                                } label: {
                                    Label("制覇マップ", systemImage: "map.fill")
                                }
                            }
                        }

                        Section("タイムライン") {
                            ForEach(visits) { visit in
                                TimelineRow(visit: visit)
                            }
                        }
                    }
                }
            }
            .navigationTitle("記録")
        }
    }

    private var thisYearCount: Int {
        let year = Calendar.current.component(.year, from: .now)
        return visits.filter {
            Calendar.current.component(.year, from: $0.visitedAt) == year
        }.count
    }

    /// 訪問済みスポットがある都道府県の数。集計は保存済みの prefecture を読むだけ。
    private var conqueredPrefectureCount: Int {
        let names = places
            .filter { !$0.isArchived && $0.isVisited }
            .compactMap { PrefectureGrid.normalize($0.prefecture) }
        return Set(names).count
    }

    private var summary: some View {
        HStack {
            statistic(value: "\(visits.count)", caption: "訪問")
            Divider()
            statistic(value: "\(thisYearCount)", caption: "今年")
            Divider()
            statistic(value: "\(Set(visits.compactMap { $0.place?.id }).count)", caption: "スポット")
            Divider()
            statistic(value: "\(conqueredPrefectureCount)", caption: "都道府県")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func statistic(value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineRow: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(visit.place?.name ?? "（削除されたスポット）")
                    .font(.body.weight(.medium))
                Spacer()
                Text(visit.visitedAt, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !visit.memo.isEmpty {
                Text(visit.memo)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RecordTabView()
        .modelContainer(SpotKeeperModelContainer.preview())
}
