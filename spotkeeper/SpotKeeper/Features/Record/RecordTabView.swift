import SwiftData
import SwiftUI

/// 記録タブ。V1 では訪問タイムラインと制覇マップがここに入る。
/// 現段階ではタイムラインのみ。
struct RecordTabView: View {
    @Query(sort: \Visit.visitedAt, order: .reverse) private var visits: [Visit]

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

    private var summary: some View {
        HStack {
            statistic(value: "\(visits.count)", caption: "訪問")
            Divider()
            statistic(value: "\(thisYearCount)", caption: "今年")
            Divider()
            statistic(value: "\(Set(visits.compactMap { $0.place?.id }).count)", caption: "スポット")
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
