import MapKit
import SwiftData
import SwiftUI

/// ピンをタップすると下から立ち上がるスポット詳細。
///
/// チェックインはこのシートの最上部に置く。地図でピンを押す → 1タップ、が
/// 記録までの最短経路であり、この導線の短さがアプリの継続率を決める。
struct PlaceDetailSheet: View {
    @Bindable var place: Place

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var justCheckedIn = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    checkInButton
                    routeButtons
                }

                if !place.note.isEmpty {
                    Section("場所メモ") {
                        Text(place.note)
                            .font(.callout)
                    }
                }

                Section {
                    LabeledContent("分類", value: place.category.label)
                    if let address = place.address {
                        LabeledContent("住所", value: address)
                    }
                    LabeledContent("訪問回数", value: "\(place.visitCount) 回")
                }

                visitHistorySection
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var checkInButton: some View {
        Button {
            checkIn()
        } label: {
            Label(
                justCheckedIn ? "記録しました" : "チェックイン",
                systemImage: justCheckedIn ? "checkmark.circle.fill" : "mappin.and.ellipse"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(justCheckedIn ? .green : .pinVisited)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var routeButtons: some View {
        HStack(spacing: 10) {
            Button {
                openInAppleMaps()
            } label: {
                Label("マップ", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }

            Button {
                openInGoogleMaps()
            } label: {
                Label("Google マップ", systemImage: "arrow.triangle.turn.up.right.circle")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .font(.subheadline)
    }

    private var visits: [Visit] { place.sortedVisits }

    @ViewBuilder
    private var visitHistorySection: some View {
        Section("訪問履歴") {
            if visits.isEmpty {
                Text("まだ訪問の記録はありません")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(visits) { visit in
                    VisitRow(visit: visit)
                }
                .onDelete { offsets in
                    let targets = visits
                    for index in offsets {
                        context.delete(targets[index])
                    }
                }
            }
        }
    }

    @MainActor
    private func checkIn() {
        let visit = Visit(visitedAt: .now, source: .manual)
        visit.place = place
        context.insert(visit)

        withAnimation { justCheckedIn = true }

        // シートを閉じたあと、地図のピンが灰色から朱色へ切り替わるのを見せたい。
        // 少しだけ間を置いてから閉じる。
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }

    private func openInAppleMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = place.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }

    /// Google マップアプリへ経路案内を渡す。SDK も API キーも使わないため費用は発生しない。
    /// 未インストールの端末では Web 版へ落とす。
    private func openInGoogleMaps() {
        let destination = "\(place.latitude),\(place.longitude)"

        if let appURL = URL(string: "comgooglemaps://?daddr=\(destination)&directionsmode=driving"),
           UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
            return
        }

        if let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(destination)") {
            openURL(webURL)
        }
    }
}

/// 訪問履歴の1行。メモは訪問ごとに独立しているため、
/// 同じ場所でも回ごとに違う内容がそのまま並ぶ。
private struct VisitRow: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(visit.visitedAt, format: .dateTime.year().month().day())
                    .font(.subheadline.weight(.medium))
                Spacer()
                if visit.rating > 0 {
                    Text(String(repeating: "★", count: visit.rating))
                        .font(.caption)
                        .foregroundStyle(.pinWishlisted)
                }
            }

            if visit.memo.isEmpty {
                Text("メモなし")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(visit.memo)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let cost = visit.cost {
                Text("\(cost) 円")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
