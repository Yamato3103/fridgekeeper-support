import SwiftUI
import UIKit

/// 経路3の入力画面。Google マップの共有 URL を貼り付けて取り込む。
///
/// 本来は Share Extension から直接受けたいが、まず本体側で取り込めるようにしておく。
/// 取り込みに失敗しても行き止まりにしないよう、手動登録への逃げ道を必ず出す。
struct GoogleMapsImportView: View {
    @State private var urlText = ""
    @State private var draft: PlaceDraft?
    @State private var errorMessage: String?
    @State private var isImporting = false

    @Environment(\.dismiss) private var dismiss

    /// 取り込みに失敗したとき、地図での手動登録へ切り替えるための通知。
    var onFallbackToMap: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://maps.app.goo.gl/...", text: $urlText, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout)

                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Google マップの共有 URL")
                } footer: {
                    Text("Google マップでスポットを開き、共有 → リンクをコピー して貼り付けてください。")
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
            .navigationTitle("URL から取り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("取り込む") { importURL() }
                        .disabled(urlText.isEmpty || isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("読み込み中")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .sheet(item: $draft) { draft in
                NewPlaceFormView(draft: draft)
            }
        }
    }

    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string {
            urlText = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = nil
        }
    }

    private func importURL() {
        errorMessage = nil

        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "URL の形式が正しくないようです。"
            return
        }

        isImporting = true
        Task {
            do {
                draft = try await GoogleMapsURLImporter.makeDraft(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }
}

#Preview {
    GoogleMapsImportView(onFallbackToMap: {})
        .modelContainer(SpotKeeperModelContainer.preview())
}
