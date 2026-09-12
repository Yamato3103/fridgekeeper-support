import SwiftData
import SwiftUI

struct ListTabView: View {
    @Query(sort: \Place.createdAt, order: .reverse) private var allPlaces: [Place]

    @State private var filter: Filter = .all
    @State private var selectedPlace: Place?

    enum Filter: String, CaseIterable, Identifiable {
        case all, unvisited, visited
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "すべて"
            case .unvisited: "未訪問"
            case .visited: "訪問済み"
            }
        }
    }

    private var places: [Place] {
        allPlaces
            .filter { !$0.isArchived }
            .filter { place in
                switch filter {
                case .all: true
                case .unvisited: !place.isVisited
                case .visited: place.isVisited
                }
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty {
                    ContentUnavailableView(
                        "スポットがありません",
                        systemImage: "mappin.slash",
                        description: Text("地図を長押しするか、検索して行きたい場所を登録してください。")
                    )
                } else {
                    List(places) { place in
                        Button {
                            selectedPlace = place
                        } label: {
                            PlaceRow(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("リスト")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("表示", selection: $filter) {
                        ForEach(Filter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct PlaceRow: View {
    let place: Place

    private var state: PlacePinState { PlacePinState(place: place) }

    var body: some View {
        HStack(spacing: 12) {
            PlacePinView(place: place)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 6) {
                    Text(place.category.label)
                    if place.isVisited, let last = place.lastVisitedAt {
                        Text("·")
                        Text("最終 \(last, format: .dateTime.year().month().day())")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if place.visitCount > 0 {
                Text("\(place.visitCount)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.pinVisited)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    ListTabView()
        .modelContainer(SpotKeeperModelContainer.preview())
}
