import MapKit
import SwiftData
import SwiftUI
import UIKit

/// 起点となる地図タブ。
struct MapTabView: View {
    @Query(sort: \Place.createdAt, order: .reverse) private var allPlaces: [Place]

    @StateObject private var locationProvider = LocationProvider()

    @State private var cameraPosition: MapCameraPosition = .region(.japan)
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedPlace: Place?

    @State private var route: AddPlaceRoute?
    @State private var draftFromLongPress: PlaceDraft?
    @State private var showsLongPressHint = false

    /// スポット登録の4経路。入口は違っても、最後は NewPlaceFormView に合流する。
    enum AddPlaceRoute: String, Identifiable {
        case search
        case googleMapsURL
        case photo
        var id: String { rawValue }
    }

    private var places: [Place] {
        allPlaces.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    ForEach(places) { place in
                        Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                            PlacePinView(place: place, isSelected: selectedPlace?.id == place.id)
                                .onTapGesture { selectedPlace = place }
                        }
                        .annotationTitles(.hidden)
                    }

                    if locationProvider.isAuthorized {
                        UserAnnotation()
                    }
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .gesture(longPressGesture(proxy: proxy))
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .safeAreaInset(edge: .bottom) { legend }
            .navigationTitle("地図")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { addMenu }
                ToolbarItem(placement: .topBarLeading) { locateButton }
            }
            .task {
                locationProvider.requestAuthorization()
                locationProvider.requestCurrentLocation()
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $draftFromLongPress) { draft in
                NewPlaceFormView(draft: draft)
            }
            .sheet(item: $route) { route in
                switch route {
                case .search:
                    PlaceSearchView(region: visibleRegion)
                case .googleMapsURL:
                    GoogleMapsImportView(onFallbackToMap: { showsLongPressHint = true })
                case .photo:
                    PhotoImportView(onFallbackToMap: { showsLongPressHint = true })
                }
            }
            .alert("地図を長押し", isPresented: $showsLongPressHint) {
                Button("わかりました", role: .cancel) {}
            } message: {
                Text("登録したい場所を地図上で長押しすると、その地点をスポットとして登録できます。")
            }
        }
    }

    // MARK: - 登録の入口

    private var addMenu: some View {
        Menu {
            Button {
                route = .search
            } label: {
                Label("検索して追加", systemImage: "magnifyingglass")
            }

            Button {
                route = .googleMapsURL
            } label: {
                Label("Google マップの URL から", systemImage: "link")
            }

            Button {
                route = .photo
            } label: {
                Label("写真から", systemImage: "photo")
            }

            Section {
                Button {
                    showsLongPressHint = true
                } label: {
                    Label("地図を長押しして追加", systemImage: "hand.tap")
                }
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }

    /// 経路2: 地図の長押し。
    ///
    /// 長押しだけでは押された座標が取れないため、長押しの成立後に
    /// 移動量ゼロのドラッグを繋いで位置を受け取り、MapProxy で緯度経度へ変換する。
    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard
                    case let .second(true, drag?) = value,
                    let coordinate = proxy.convert(drag.location, from: .local)
                else {
                    return
                }

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                draftFromLongPress = PlaceDraft(coordinate: coordinate, origin: .mapLongPress)
            }
    }

    private var locateButton: some View {
        Button {
            locationProvider.requestCurrentLocation()
            if let location = locationProvider.currentLocation {
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                        )
                    )
                }
            }
        } label: {
            Image(systemName: locationProvider.isAuthorized ? "location.fill" : "location")
        }
    }

    // MARK: - 凡例

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
