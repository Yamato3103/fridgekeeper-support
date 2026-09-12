import SwiftData
import SwiftUI

@main
struct SpotKeeperApp: App {
    private let container = SpotKeeperModelContainer.live()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    #if DEBUG
                    // 開発中は空の地図だとピンの状態設計を確認できないため、
                    // データが1件も無いときだけサンプルを入れる。
                    SampleData.seedIfEmpty(container.mainContext)
                    #endif
                }
        }
        .modelContainer(container)
    }
}
