import MapKit
import SwiftUI

/// 経路1: アプリ内検索。
struct PlaceSearchView: View {
    let region: MKCoordinateRegion?

    @StateObject private var service = PlaceSearchService()
    @State private var query = ""
    @State private var draft: PlaceDraft?
    @State private var isResolving = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        "スポットを検索",
                        systemImage: "magnifyingglass",
                        description: Text("店名や施設名を入力してください。表示中の地図の周辺が優先されます。")
                    )
                } else if service.suggestions.isEmpty && !service.isSearching {
                    ContentUnavailableView(
                        "見つかりません",
                        systemImage: "mappin.slash",
                        description: Text("地図を長押しして手で登録するか、Google マップで見つけて共有してください。")
                    )
                } else {
                    List(service.suggestions) { suggestion in
                        Button {
                            resolve(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "店名・施設名")
            .onChange(of: query) { _, newValue in
                service.updateQuery(newValue, around: region)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .overlay {
                if isResolving {
                    ProgressView()
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .sheet(item: $draft) { draft in
                NewPlaceFormView(draft: draft)
            }
        }
    }

    private func resolve(_ suggestion: PlaceSuggestion) {
        isResolving = true
        Task {
            draft = await service.resolve(suggestion)
            isResolving = false
        }
    }
}

#Preview {
    PlaceSearchView(region: .japan)
        .modelContainer(SpotKeeperModelContainer.preview())
}
