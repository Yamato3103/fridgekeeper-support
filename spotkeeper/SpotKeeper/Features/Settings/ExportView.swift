import SwiftData
import SwiftUI

/// 書き出し画面。
///
/// 画面を開いた時点で両形式のファイルを作っておき、あとは共有するだけにする。
/// 「作る」と「共有する」を2タップに分けると、押し間違いと待ちが挟まって面倒になる。
struct ExportView: View {
    @Query(sort: \Place.createdAt) private var allPlaces: [Place]

    @State private var files: [ExportService.Format: URL] = [:]
    @State private var isPreparing = true
    @State private var errorMessage: String?

    private var places: [Place] { allPlaces.filter { !$0.isArchived } }

    private var visitCount: Int {
        places.reduce(0) { $0 + $1.visitCount }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("スポット", value: "\(places.count) 件")
                LabeledContent("訪問記録", value: "\(visitCount) 件")
            } footer: {
                Text("写真は含まれません。書き出されるのは名前・位置・メモ・訪問の記録です。")
            }

            Section("形式") {
                ForEach(ExportService.Format.allCases) { format in
                    row(for: format)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.pinVisited)
                }
            }
        }
        .navigationTitle("書き出す")
        .navigationBarTitleDisplayMode(.inline)
        .task { await prepare() }
    }

    @ViewBuilder
    private func row(for format: ExportService.Format) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = files[format] {
                ShareLink(item: url) {
                    Label(format.label, systemImage: "square.and.arrow.up")
                }
            } else {
                HStack {
                    Label(format.label, systemImage: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isPreparing {
                        ProgressView()
                    }
                }
            }

            Text(format.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func prepare() async {
        isPreparing = true
        defer { isPreparing = false }

        var prepared: [ExportService.Format: URL] = [:]

        for format in ExportService.Format.allCases {
            do {
                prepared[format] = try ExportService.export(places, as: format)
            } catch {
                errorMessage = "\(format.label) を書き出せませんでした: \(error.localizedDescription)"
            }
        }

        files = prepared
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
    .modelContainer(SpotKeeperModelContainer.preview())
}
