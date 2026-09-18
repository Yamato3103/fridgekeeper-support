import SwiftUI

/// タブは3つに絞る。4つ以上になると片手操作での迷いが増えるため、
/// 設定はリストタブのツールバーに置く方針。
struct RootTabView: View {
    var body: some View {
        TabView {
            MapTabView()
                .tabItem { Label("地図", systemImage: "map") }

            ListTabView()
                .tabItem { Label("リスト", systemImage: "list.bullet") }

            RecordTabView()
                .tabItem { Label("記録", systemImage: "book.closed") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(SpotKeeperModelContainer.preview())
}
