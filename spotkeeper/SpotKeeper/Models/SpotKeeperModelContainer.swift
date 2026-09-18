import Foundation
import SwiftData

enum SpotKeeperModelContainer {

    /// iCloud 同期のスイッチ。
    ///
    /// `true` にする前に、Xcode の Signing & Capabilities で
    ///   - iCloud → CloudKit にチェックを入れ、コンテナを作成する
    ///   - Background Modes → Remote notifications にチェックを入れる
    /// を済ませておくこと。entitlement が無い状態で `true` にすると起動時に落ちる。
    static let isCloudKitEnabled = false

    static let schema = Schema([
        Place.self,
        Visit.self,
        VisitPhoto.self,
    ])

    /// アプリ本体が使うコンテナ。
    static func live() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: isCloudKitEnabled ? .automatic : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // 起動できない以上、握りつぶしても無意味なので原因を出して止める。
            fatalError("ModelContainer を生成できませんでした: \(error)")
        }
    }

    /// プレビューと動作確認用。メモリ上だけで動き、サンプルデータが入った状態で開く。
    @MainActor
    static func preview() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            SampleData.insert(into: container.mainContext)
            return container
        } catch {
            fatalError("プレビュー用 ModelContainer を生成できませんでした: \(error)")
        }
    }
}
