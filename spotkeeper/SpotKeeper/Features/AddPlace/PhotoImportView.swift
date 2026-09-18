import PhotosUI
import SwiftUI

/// 経路4: 位置情報つきの写真からスポットを登録する。
///
/// 景色が良かった場所や、店舗データベースに載っていない地点を拾うのに効く。
/// V1.1 の「写真からの訪問サジェスト」は、この読み取り処理を
/// ライブラリ全体へ広げたものになる。
struct PhotoImportView: View {
    @State private var selection: PhotosPickerItem?
    @State private var draft: PlaceDraft?
    @State private var errorMessage: String?
    @State private var isReading = false

    @Environment(\.dismiss) private var dismiss

    var onFallbackToMap: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                        Label("写真を選ぶ", systemImage: "photo.on.rectangle.angled")
                    }
                } footer: {
                    Text("撮影時に位置情報が記録された写真から、その場所をスポットとして登録します。")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.pinVisited)

                        Button {
                            dismiss()
                            onFallbackToMap()
                        } label: {
                            Label("地図を長押しして手で登録する", systemImage: "hand.tap")
                        }
                    }
                }
            }
            .navigationTitle("写真から登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .overlay {
                if isReading {
                    ProgressView("読み込み中")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onChange(of: selection) { _, newValue in
                guard let newValue else { return }
                read(newValue)
            }
            .sheet(item: $draft) { draft in
                NewPlaceFormView(draft: draft)
            }
        }
    }

    private func read(_ item: PhotosPickerItem) {
        errorMessage = nil
        isReading = true

        Task {
            if let metadata = await PhotoMetadataReader.read(from: item) {
                draft = PlaceDraft(coordinate: metadata.coordinate, origin: .photo)
            } else {
                errorMessage = "この写真には位置情報が記録されていませんでした。"
            }
            isReading = false
        }
    }
}

#Preview {
    PhotoImportView(onFallbackToMap: {})
        .modelContainer(SpotKeeperModelContainer.preview())
}
