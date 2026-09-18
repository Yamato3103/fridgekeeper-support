import SwiftData
import SwiftUI

/// サポートとプライバシーポリシーの掲載先。
///
/// 現在は冷蔵庫キーパー用のリポジトリを指している暫定値。
/// App Store 審査ではこの2つの URL が実際に開けることが確認されるため、
/// 提出前にスポットキーパー専用のページへ差し替えること。
enum SupportLinks {
    static let support = URL(string: "https://yamato3103.github.io/fridgekeeper-support/support.html")!
    static let privacyPolicy = URL(string: "https://yamato3103.github.io/fridgekeeper-support/privacy-policy.html")!
}

struct SettingsView: View {
    @Query private var places: [Place]
    @Query private var visits: [Visit]
    @Query private var photos: [VisitPhoto]

    @Environment(\.dismiss) private var dismiss

    @State private var photoBytes: Int64 = 0

    var body: some View {
        NavigationStack {
            List {
                Section("データ") {
                    LabeledContent("スポット", value: "\(places.filter { !$0.isArchived }.count) 件")
                    LabeledContent("訪問記録", value: "\(visits.count) 件")
                    LabeledContent("写真", value: "\(photos.count) 枚")
                    LabeledContent("写真の使用量", value: formattedPhotoBytes)
                }

                Section {
                    NavigationLink {
                        ExportView()
                    } label: {
                        Label("書き出す", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("CSV と GeoJSON で持ち出せます。他のアプリに移りたくなったときのために、この機能は常に無料です。")
                }

                Section {
                    LabeledContent("iCloud 同期") {
                        Text(SpotKeeperModelContainer.isCloudKitEnabled ? "オン" : "オフ")
                            .foregroundStyle(
                                SpotKeeperModelContainer.isCloudKitEnabled ? Color.primary : Color.secondary
                            )
                    }
                } header: {
                    Text("同期")
                } footer: {
                    Text(
                        SpotKeeperModelContainer.isCloudKitEnabled
                            ? "この端末のデータは iCloud を通じて他の端末と同期されます。"
                            : "現在このアプリのデータは端末内にのみ保存されています。機種変更では引き継がれないため、定期的な書き出しをおすすめします。"
                    )
                }

                Section("このアプリについて") {
                    LabeledContent("バージョン", value: appVersion)
                    Link(destination: SupportLinks.support) {
                        Label("サポート", systemImage: "questionmark.circle")
                    }
                    Link(destination: SupportLinks.privacyPolicy) {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                photoBytes = PhotoStore.totalBytes()
            }
        }
    }

    private var formattedPhotoBytes: String {
        ByteCountFormatter.string(fromByteCount: photoBytes, countStyle: .file)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(SpotKeeperModelContainer.preview())
}
