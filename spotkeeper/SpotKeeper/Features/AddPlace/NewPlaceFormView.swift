import MapKit
import SwiftData
import SwiftUI

/// 4つの登録経路すべてが最後に通る確認画面。
///
/// 名前だけ必須で、あとは後から直せる。ここで入力項目を増やすと
/// 「登録が面倒」という理由で使われなくなるため、意図的に薄くしてある。
struct NewPlaceFormView: View {
    @State var draft: PlaceDraft

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isNameFocused: Bool
    @State private var isGeocoding = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("スポット名", text: $draft.name)
                        .focused($isNameFocused)

                    Picker("分類", selection: $draft.category) {
                        ForEach(PlaceCategory.allCases) { category in
                            Label(category.label, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                } header: {
                    Text(draft.origin.label)
                }

                Section("行きたい度") {
                    Picker("行きたい度", selection: $draft.wishLevel) {
                        Text("なし").tag(0)
                        Text("低").tag(1)
                        Text("中").tag(2)
                        Text("高").tag(3)
                    }
                    .pickerStyle(.segmented)

                    if draft.wishLevel >= 2 {
                        Label("地図上で優先スポットとして表示されます", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.pinWishlisted)
                    }
                }

                Section("場所メモ") {
                    TextField(
                        "駐車場・定休日など、何度行っても変わらない情報",
                        text: $draft.note,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                Section("位置") {
                    LocationPreviewMap(coordinate: draft.coordinate)
                        .frame(height: 150)
                        .listRowInsets(EdgeInsets())

                    if isGeocoding {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("住所を取得中")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    } else if let address = draft.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(String(format: "%.5f, %.5f", draft.coordinate.latitude, draft.coordinate.longitude))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("スポットを登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("登録") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .task {
                if draft.address == nil {
                    await resolveAddress()
                }
                if draft.name.isEmpty {
                    isNameFocused = true
                }
            }
        }
    }

    /// 住所と都道府県はこの1回だけ引く。CLGeocoder の回数制限を踏まないため、
    /// 以降は Place に保存された値を使い回す。
    private func resolveAddress() async {
        isGeocoding = true
        defer { isGeocoding = false }

        guard let address = await PlaceGeocoder.reverseGeocode(draft.coordinate) else { return }
        draft.address = address.formatted
        pendingPrefecture = address.prefecture
        pendingMunicipality = address.municipality
    }

    @State private var pendingPrefecture: String?
    @State private var pendingMunicipality: String?

    private func save() {
        let place = draft.makePlace()
        place.prefecture = pendingPrefecture
        place.municipality = pendingMunicipality
        context.insert(place)
        dismiss()
    }
}

/// 登録位置を確認するための、操作できない小さな地図。
private struct LocationPreviewMap: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                )
            ),
            interactionModes: []
        ) {
            Marker("", coordinate: coordinate)
                .tint(.pinVisited)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NewPlaceFormView(
        draft: PlaceDraft(
            name: "",
            coordinate: .init(latitude: 35.6586, longitude: 139.7454),
            origin: .mapLongPress
        )
    )
    .modelContainer(SpotKeeperModelContainer.preview())
}
