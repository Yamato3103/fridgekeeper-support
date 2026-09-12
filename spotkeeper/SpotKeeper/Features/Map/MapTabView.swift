import MapKit
import SwiftData
import SwiftUI

/// 起点となる地図タブ。
struct MapTabView: View {
    @Query(sort: \Place.createdAt, order: .reverse) private var allPlaces: [Place]

    @State private var cameraPosition: MapCameraPosition = .region(.japan)
    @State private var selectedPlace: Place?

    private var places: [Place] {
        allPlaces.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(places) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                        PlacePinView(place: place, isSelected: selectedPlace?.id == place.id)
                            .onTapGesture { selectedPlace = place }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) { legend }
            .navigationTitle("地図")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    /// ピンの読み方をその場で示す凡例。
    /// 状態が5つあるため、初見で色と形の意味が分かるようにしておく。
    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: .pinIdle, filled: false, text: "未訪問")
            legendItem(color: .pinWishlisted, filled: false, text: "優先")
            legendItem(color: .pinVisited, filled: true, text: "訪問済み")
        }
        .font(.caption2)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 10)
    }

    private func legendItem(color: Color, filled: Bool, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(filled ? color : .clear)
                .overlay { Circle().strokeBorder(color, lineWidth: filled ? 0 : 2) }
                .frame(width: 11, height: 11)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

extension MKCoordinateRegion {
    /// 日本列島がひと目に収まる初期表示。
    /// 現在地の取得は権限付与後に行うため、起動直後はこの範囲から始める。
    static let japan = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2, longitude: 137.9),
        span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14)
    )
}

#Preview {
    MapTabView()
        .modelContainer(SpotKeeperModelContainer.preview())
}
