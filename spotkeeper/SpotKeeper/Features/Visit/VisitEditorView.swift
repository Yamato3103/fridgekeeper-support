import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 1回の訪問の記録を編集する。
///
/// チェックインの時点では何も入力させず、後からここで埋める。
/// 記録アプリが続かない最大の理由は入力の面倒さなので、
/// すべての項目を任意のままにし、途中で閉じても失われないよう
/// モデルへ直接束縛して即時保存する（キャンセルは設けない）。
struct VisitEditorView: View {
    @Bindable var visit: Visit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("訪問日時") {
                    DatePicker(
                        "訪問日時",
                        selection: $visit.visitedAt,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }

                Section("メモ") {
                    TextField(
                        "この訪問の記録",
                        text: $visit.memo,
                        axis: .vertical
                    )
                    .lineLimit(3...12)
                }

                Section("評価") {
                    StarRatingView(rating: $visit.rating)
                }

                Section("記録") {
                    LabeledContent("費用") {
                        HStack(spacing: 4) {
                            TextField("未入力", value: costBinding, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("円")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("同行者") {
                        TextField("未入力", text: companionsBinding)
                            .multilineTextAlignment(.trailing)
                    }
                }

                photosSection

                Section {
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("この訪問を削除", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(visit.visitedAt.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .onChange(of: pickerItems) { _, newValue in
                guard !newValue.isEmpty else { return }
                importPhotos(newValue)
            }
            .alert("この訪問を削除しますか", isPresented: $showsDeleteConfirmation) {
                Button("削除", role: .destructive) { deleteVisit() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("メモと写真も一緒に削除されます。元に戻せません。")
            }
            .alert(
                "写真を取り込めませんでした",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 写真

    @ViewBuilder
    private var photosSection: some View {
        Section("写真") {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            PhotoThumbnail(photo: photo) {
                                delete(photo)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(photos.isEmpty ? "写真を追加" : "さらに追加", systemImage: "photo.badge.plus")
            }
            .disabled(isImportingPhotos)

            if isImportingPhotos {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("取り込み中")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private var photos: [VisitPhoto] { visit.sortedPhotos }

    /// 原寸はファイルへ、サムネイルはモデルへ。撮影位置と日時も一緒に拾っておく。
    /// V1.1 の訪問サジェストがこの値を使う。
    private func importPhotos(_ items: [PhotosPickerItem]) {
        isImportingPhotos = true

        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

                do {
                    let stored = try PhotoStore.save(data)
                    let metadata = PhotoMetadataReader.readEXIF(from: data)

                    let photo = VisitPhoto(
                        fileName: stored.fileName,
                        thumbnailData: stored.thumbnail,
                        capturedAt: metadata?.capturedAt,
                        latitude: metadata?.coordinate.latitude,
                        longitude: metadata?.coordinate.longitude
                    )
                    photo.visit = visit
                    context.insert(photo)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

            pickerItems = []
            isImportingPhotos = false
        }
    }

    /// モデルを消すだけではファイルが残るので、実体も一緒に消す。
    private func delete(_ photo: VisitPhoto) {
        PhotoStore.delete(fileName: photo.fileName)
        context.delete(photo)
    }

    private func deleteVisit() {
        for photo in photos {
            PhotoStore.delete(fileName: photo.fileName)
        }
        context.delete(visit)
        dismiss()
    }

    // MARK: - Optional なフィールドの束縛

    private var costBinding: Binding<Int> {
        Binding(
            get: { visit.cost ?? 0 },
            set: { visit.cost = $0 <= 0 ? nil : $0 }
        )
    }

    private var companionsBinding: Binding<String> {
        Binding(
            get: { visit.companions ?? "" },
            set: { visit.companions = $0.isEmpty ? nil : $0 }
        )
    }
}

/// 写真1枚。長押しで削除できる。
private struct PhotoThumbnail: View {
    let photo: VisitPhoto
    let onDelete: () -> Void

    var body: some View {
        Group {
            if let data = photo.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
        }
    }
}
