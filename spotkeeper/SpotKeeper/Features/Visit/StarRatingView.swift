import SwiftUI

/// 5段階の評価。0 は未評価で、同じ星をもう一度押すと 0 に戻せる。
///
/// 評価を必須にすると記録が止まるため、「付けない」という選択を
/// いつでも取り戻せるようにしておく。
struct StarRatingView: View {
    @Binding var rating: Int
    var isEditable = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(value <= rating ? Color.pinWishlisted : Color.secondary.opacity(0.4))
                    .onTapGesture {
                        guard isEditable else { return }
                        rating = (rating == value) ? 0 : value
                    }
                    .accessibilityLabel("\(value) つ星")
                    .accessibilityAddTraits(isEditable ? .isButton : [])
            }

            if rating > 0, isEditable {
                Button("クリア") { rating = 0 }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
        }
    }
}

/// プレビュー用の入れ物。@Previewable は Xcode 16 以降でしか使えないため、
/// 状態を持つ小さな View を挟んでおく。
private struct StarRatingPreview: View {
    @State private var rating = 3

    var body: some View {
        StarRatingView(rating: $rating)
            .padding()
    }
}

#Preview {
    StarRatingPreview()
}
