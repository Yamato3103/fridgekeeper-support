import MapKit
import SwiftData
import SwiftUI
import UIKit

/// ピンをタップすると下から立ち上がるスポット詳細。
///
/// チェックインはこのシートの最上部に置く。地図でピンを押す → 1タップ、が
/// 記録までの最短経路であり、この導線の短さがアプリの継続率を決める。
struct PlaceDetailSheet: View {
    @Bindable var place: Place

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// 直前のチェックインで作られた訪問。「メモを追加」の行き先になる。
    @State private var justCreatedVisit: Visit?
    @State private var editingVisit: Visit?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    checkInButton
                    if let justCreatedVisit {
                        addMemoButton(for: justCreatedVisit)
                    }
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
            .sheet(item: $editingVisit) { visit in
                VisitEditorView(visit: visit)
            }
        }
    }

    // MARK: - チェックイン

    private var checkInButton: some View {
        Button {
            checkIn()
        } label: {
            Label(
                justCreatedVisit == nil ? "チェックイン" : "記録しました",
                systemImage: justCreatedVisit == nil ? "mappin.and.ellipse" : "checkmark.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(justCreatedVisit == nil ? .pinVisited : .green)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    /// チェックイン直後に入力を強制しないための導線。
    /// 押さなければ日時だけの記録として残り、後から履歴をタップして埋められる。
    private func addMemoButton(for visit: Visit) -> some View {
        Button {
            editingVisit = visit
        } label: {
            Label("メモや写真を追加", systemImage: "square.and.pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.subheadline)
    }

    @MainActor
    private func checkIn() {
        if let justCreatedVisit {
            // 二重チェックインの受け皿。連打しても訪問が増えないようにする。
            editingVisit = justCreatedVisit
            return
        }

        let visit = Visit(visitedAt: .now, source: .manual)
        visit.place = place
        context.insert(visit)

        withAnimation {
            justCreatedVisit = visit
        }
    }

    // MARK: - 経路案内

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

    // MARK: - 訪問履歴

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
                    Button {
                        editingVisit = visit
                    } label: {
                        VisitRow(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    delete(at: offsets)
                }
            }
        }
    }

    /// 訪問を消すときは写真の実体も消す。モデルの cascade はファイルまでは面倒を見ない。
    private func delete(at offsets: IndexSet) {
        let targets = visits
        for index in offsets {
            let visit = targets[index]
            for photo in visit.sortedPhotos {
                PhotoStore.delete(fileName: photo.fileName)
            }
            if visit.id == justCreatedVisit?.id {
                justCreatedVisit = nil
            }
            context.delete(visit)
        }
    }
}

/// 訪問履歴の1行。メモは訪問ごとに独立しているため、
/// 同じ場所でも回ごとに違う内容がそのまま並ぶ。
private struct VisitRow: View {
    let visit: Visit

    private var photos: [VisitPhoto] { visit.sortedPhotos }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(visit.visitedAt, format: .dateTime.year().month().day())
                    .font(.subheadline.weight(.medium))
                Spacer()
                if visit.rating > 0 {
                    Text(String(repeating: "★", count: visit.rating))
                        .font(.caption)
                        .foregroundStyle(.pinWishlisted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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

            if !photos.isEmpty {
                HStack(spacing: 6) {
                    ForEach(photos.prefix(4)) { photo in
                        thumbnail(for: photo)
                    }
                    if photos.count > 4 {
                        Text("+\(photos.count - 4)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let cost = visit.cost {
                Text("\(cost) 円")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func thumbnail(for photo: VisitPhoto) -> some View {
        if let data = photo.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
